using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
using DataType = Microsoft.SqlServer.Dts.Runtime.Wrapper.DataType;
using IDTSConnectionManagerFlatFile100 = Microsoft.SqlServer.Dts.Runtime.Wrapper.IDTSConnectionManagerFlatFile100;
using IDTSName100 = Microsoft.SqlServer.Dts.Runtime.Wrapper.IDTSName100;
using Microsoft.SqlServer.Dts.Tasks.ExecuteSQLTask;

// Uses the installed SSIS 2022 object model. No registration or machine settings change.
internal static class SsisTools {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct ACTCTX { public int cbSize; public uint dwFlags; public string lpSource;
        public ushort arch, language; public string directory, resource, application; public IntPtr module; }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr CreateActCtx(ref ACTCTX ctx);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool ActivateActCtx(IntPtr ctx, out UIntPtr cookie);
    [DllImport("kernel32.dll")] static extern bool DeactivateActCtx(uint flags, UIntPtr cookie);
    [DllImport("kernel32.dll")] static extern void ReleaseActCtx(IntPtr ctx);

    sealed class Events : DefaultEvents {
        public override bool OnError(DtsObject source, int code, string sub, string message,
                                     string help, int context, string id) {
            Console.Error.WriteLine("ERROR " + code.ToString("X8") + " | " + sub + " | " + message);
            return false;
        }
        public override void OnInformation(DtsObject source, int code, string sub, string message,
                                           string help, int context, string id, ref bool again) {
            if (!message.Contains("Validation phase") && !message.Contains("Prepare for Execute"))
                Console.WriteLine("INFO | " + sub + " | " + message);
        }
    }
    sealed class Column { public string Name, Type; public int Length, Precision, Scale; }
    static string Q(string value) { return "[" + value.Replace("]", "]]") + "]"; }
    static string Literal(string value) { return "N'" + value.Replace("'", "''") + "'"; }
    static string SqlConnection(string server) {
        return new SqlConnectionStringBuilder { DataSource=server, InitialCatalog="HomeCreditBI",
            IntegratedSecurity=true, TrustServerCertificate=true, ConnectTimeout=15 }.ConnectionString;
    }
    static string OleConnection(string server) {
        var b = new System.Data.OleDb.OleDbConnectionStringBuilder();
        b["Provider"]="MSOLEDBSQL"; b["Data Source"]=server; b["Initial Catalog"]="HomeCreditBI";
        b["Integrated Security"]="SSPI"; b["Trust Server Certificate"]=true;
        return b.ConnectionString;
    }
    static List<Column> Columns(string server, string table) {
        var list = new List<Column>();
        using(var conn = new SqlConnection(SqlConnection(server))) {
            conn.Open();
            using(var cmd=conn.CreateCommand()) {
                cmd.CommandText="SELECT COLUMN_NAME,DATA_TYPE,COALESCE(CHARACTER_MAXIMUM_LENGTH,0),"
                    + "COALESCE(NUMERIC_PRECISION,0),COALESCE(NUMERIC_SCALE,0) FROM INFORMATION_SCHEMA.COLUMNS "
                    + "WHERE TABLE_SCHEMA='stg' AND TABLE_NAME=@table AND COLUMN_NAME NOT IN "
                    + "('StagingRowID','BatchID','LoadedAtUtc') ORDER BY ORDINAL_POSITION";
                cmd.Parameters.AddWithValue("@table",table);
                using(var r=cmd.ExecuteReader()) while(r.Read()) list.Add(new Column {
                    Name=r.GetString(0),Type=r.GetString(1),Length=Convert.ToInt32(r.GetValue(2)),
                    Precision=Convert.ToInt32(r.GetValue(3)),Scale=Convert.ToInt32(r.GetValue(4)) });
            }
        }
        return list;
    }
    static Package NewPackage(string name) {
        var p=new Package { Name=name, ProtectionLevel=DTSProtectionLevel.DontSaveSensitive,
            DelayValidation=true, MaximumErrorCount=0 };
        p.Variables.Add("ServerInstance",false,"User",@".\SQLEXPRESS");
        p.Variables.Add("BatchID",false,"User",(long)0);
        p.Variables.Add("PreparedRoot",false,"User","");
        p.Variables.Add("FileLoadID",false,"User",(long)0);
        p.Variables.Add("SourceFileID",false,"User",0);
        p.Variables.Add("RowsRead",false,"User",(long)0);
        p.Variables.Add("RowsRejected",false,"User",(long)0);
        return p;
    }
    static ConnectionManager SqlManager(Package p,string server) {
        var cm=p.Connections.Add("OLEDB"); cm.Name="CM_HomeCreditBI";
        cm.ConnectionString=OleConnection(server);
        return cm;
    }
    static void Parameterize(ConnectionManager cm) {
        cm.SetExpression("ConnectionString","\"Provider=MSOLEDBSQL;Data Source=\" + @[User::ServerInstance] + "
            + "\";Initial Catalog=HomeCreditBI;Integrated Security=SSPI;Trust Server Certificate=True;\"");
    }
    static TaskHost SqlTask(Executables tasks,string name,string sql,ConnectionManager cm,
                            string[] inputVariables=null, string resultVariable=null) {
        var host=(TaskHost)tasks.Add("STOCK:SQLTask"); host.Name=name;
        host.DelayValidation=true; host.FailPackageOnFailure=true;
        var task=(ExecuteSQLTask)host.InnerObject;
        task.Connection=cm.ID; task.SqlStatementSource=sql; task.TimeOut=0;
        if(inputVariables!=null) for(int i=0;i<inputVariables.Length;i++) {
            var map=task.ParameterBindings.Add(); map.ParameterName=i.ToString(CultureInfo.InvariantCulture);
            map.DtsVariableName="User::"+inputVariables[i]; map.ParameterDirection=ParameterDirections.Input;
            map.DataType=20; map.ParameterSize=-1;
        }
        if(resultVariable!=null) {
            task.ResultSetType=ResultSetType.ResultSetType_SingleRow;
            var result=task.ResultSetBindings.Add(); result.ResultName="0"; result.DtsVariableName="User::"+resultVariable;
        }
        return host;
    }
    static void ExtraStringParameter(TaskHost host,int index,string variable) {
        var map=((ExecuteSQLTask)host.InnerObject).ParameterBindings.Add();
        map.ParameterName=index.ToString(CultureInfo.InvariantCulture); map.DtsVariableName=variable;
        map.ParameterDirection=ParameterDirections.Input; map.DataType=130; map.ParameterSize=128;
    }
    static void Success(Package p,Executable from,Executable to) {
        p.PrecedenceConstraints.Add(from,to).Value=DTSExecResult.Success;
    }
    static void Connect(MainPipe pipe,IDTSComponentMetaData100 from,IDTSComponentMetaData100 to) {
        pipe.PathCollection.New().AttachPathAndPropagateNotifications(from.OutputCollection[0],to.InputCollection[0]);
    }
    static IDTSComponentMetaData100 Component(MainPipe pipe,string id,string name) {
        var component=pipe.ComponentMetaDataCollection.New(); component.ComponentClassID=id;
        component.Instantiate().ProvideComponentProperties(); component.Name=name;
        return component;
    }
    static void SelectInputs(IDTSComponentMetaData100 component,string[] names=null) {
        var wrapper=component.Instantiate(); var input=component.InputCollection[0]; var virtualInput=input.GetVirtualInput();
        foreach(IDTSVirtualInputColumn100 col in virtualInput.VirtualInputColumnCollection)
            if(names==null || names.Contains(col.Name)) wrapper.SetUsageType(input.ID,virtualInput,col.LineageID,DTSUsageType.UT_READONLY);
    }
    static void OutputType(IDTSOutputColumn100 col,Column schema) {
        if(schema.Type=="bigint") col.SetDataTypeProperties(DataType.DT_I8,0,0,0,0);
        else if(schema.Type=="decimal") col.SetDataTypeProperties(DataType.DT_NUMERIC,0,schema.Precision,schema.Scale,0);
        else if(schema.Type=="nvarchar") col.SetDataTypeProperties(DataType.DT_WSTR,schema.Length,0,0,0);
        else throw new InvalidOperationException("Unsupported staging type: "+schema.Type);
    }
    static string Expression(Column schema) {
        string raw="[raw_"+schema.Name+"]";
        return schema.Type=="nvarchar" ? "(DT_WSTR,"+schema.Length+")"+raw : raw;
    }
    static void BuildLoader(string project,string server,string prepared,string file,string table,int ordinal) {
        var columns=Columns(server,table);
        string sample=Path.Combine(prepared,file);
        string[] header=File.ReadLines(sample).First().TrimEnd('\r').Split(',');
        if(!header.SequenceEqual(columns.Select(c=>c.Name)))
            throw new InvalidOperationException("CSV header and deployed SQL schema disagree: "+file);
        var p=NewPackage(ordinal.ToString("00")+"_Load_"+table);
        var sql=SqlManager(p,server);
        string target="stg."+Q(table);
        var start=SqlTask(p.Executables,"01 Check shared batch and start file audit",
            "SET NOCOUNT ON; DECLARE @B BIGINT=?; IF EXISTS(SELECT 1 FROM "+target+" WHERE BatchID=@B) "
            + "THROW 51400,'Selected source already has staging rows for this batch. Refusing duplicates.',1; "
            + "IF EXISTS(SELECT 1 FROM ctl.ETLFileLoad f JOIN ctl.SourceFile s ON s.SourceFileID=f.SourceFileID "
            + "WHERE f.BatchID=@B AND s.FileName="+Literal(file)+" AND f.LoadStatus IN ('RUNNING','SUCCEEDED')) "
            + "THROW 51401,'File audit already running or succeeded. Check previous execution.',1; "
            + "DECLARE @F BIGINT,@S INT; EXEC ctl.usp_StartFileLoad @BatchID=@B,@FileName="+Literal(file)
            + ",@FileLoadID=@F OUTPUT,@SourceFileID=@S OUTPUT;",sql,new[]{"BatchID"},"FileLoadID");
        var sourceIdResult=((ExecuteSQLTask)start.InnerObject).ResultSetBindings.Add();
        sourceIdResult.ResultName="1"; sourceIdResult.DtsVariableName="User::SourceFileID";

        var flat=p.Connections.Add("FLATFILE"); flat.Name="CM_"+table+"_CSV"; flat.ConnectionString=sample;
        var flatDetails=(IDTSConnectionManagerFlatFile100)flat.InnerObject;
        flatDetails.Format="Delimited"; flatDetails.ColumnNamesInFirstDataRow=true;
        flatDetails.TextQualifier="\""; flatDetails.Unicode=false; flatDetails.CodePage=65001;
        flatDetails.HeaderRowDelimiter="\r\n"; flatDetails.RowDelimiter="\r\n";
        for(int i=0;i<columns.Count;i++) {
            var col=flatDetails.Columns.Add(); col.ColumnType="Delimited";
            col.TextQualified=true;
            col.ColumnDelimiter=i==columns.Count-1?"\r\n":",";
            if(columns[i].Type=="bigint") col.DataType=DataType.DT_I8;
            else if(columns[i].Type=="decimal") {
                col.DataType=DataType.DT_NUMERIC; col.DataPrecision=columns[i].Precision; col.DataScale=columns[i].Scale;
            } else { col.DataType=DataType.DT_STR; col.MaximumWidth=1024; }
            ((IDTSName100)col).Name="raw_"+columns[i].Name;
        }
        var data=(TaskHost)p.Executables.Add("STOCK:PipelineTask"); data.Name="02 CSV to "+table;
        data.DelayValidation=true; data.FailPackageOnFailure=false;
        var pipe=(MainPipe)data.InnerObject;
        var source=Component(pipe,"DTSAdapter.FlatFileSource.8","Flat File Source - original values plus ordinal");
        var src=source.Instantiate(); src.SetComponentProperty("RetainNulls",true);
        source.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(flat);
        source.RuntimeConnectionCollection[0].ConnectionManagerID=flat.ID;
        src.AcquireConnections(null); src.ReinitializeMetaData(); src.ReleaseConnections();
        var count=Component(pipe,"DTSTransform.RowCount.8","Count parsed CSV records");
        count.Instantiate().SetComponentProperty("VariableName","User::RowsRead"); Connect(pipe,source,count);
        var derive=Component(pipe,"DTSTransform.DerivedColumn.8","Types and shared BatchID");
        Connect(pipe,count,derive); SelectInputs(derive);
        var derived=derive.Instantiate(); var output=derive.OutputCollection[0];
        foreach(var schema in columns) {
            var col=derived.InsertOutputColumnAt(output.ID,output.OutputColumnCollection.Count,schema.Name,"");
            OutputType(col,schema); derived.SetOutputColumnProperty(output.ID,col.ID,"Expression",Expression(schema));
            col.ErrorRowDisposition=DTSRowDisposition.RD_RedirectRow;
            col.TruncationRowDisposition=DTSRowDisposition.RD_RedirectRow;
        }
        var batch=derived.InsertOutputColumnAt(output.ID,output.OutputColumnCollection.Count,"BatchID","");
        batch.SetDataTypeProperties(DataType.DT_I8,0,0,0,0);
        derived.SetOutputColumnProperty(output.ID,batch.ID,"Expression","@[User::BatchID]");
        var loadedAt=derived.InsertOutputColumnAt(output.ID,output.OutputColumnCollection.Count,"LoadedAtUtc","");
        loadedAt.SetDataTypeProperties(DataType.DT_DBTIMESTAMP2,0,0,3,0);
        derived.SetOutputColumnProperty(output.ID,loadedAt.ID,"Expression","(DT_DBTIMESTAMP2,3)GETUTCDATE()");
        var dest=Component(pipe,"DTSAdapter.OLEDBDestination.8","Fast Load - "+table);
        var dst=dest.Instantiate(); dst.SetComponentProperty("AccessMode",3); dst.SetComponentProperty("OpenRowset",target);
        dst.SetComponentProperty("FastLoadKeepNulls",true); dst.SetComponentProperty("FastLoadOptions","TABLOCK,CHECK_CONSTRAINTS");
        dst.SetComponentProperty("FastLoadMaxInsertCommitSize",50000);
        dest.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(sql);
        dest.RuntimeConnectionCollection[0].ConnectionManagerID=sql.ID;
        dst.AcquireConnections(null); dst.ReinitializeMetaData(); dst.ReleaseConnections();
        Connect(pipe,derive,dest);
        var input=dest.InputCollection[0]; var vi=input.GetVirtualInput();
        foreach(IDTSVirtualInputColumn100 col in vi.VirtualInputColumnCollection) {
            if(col.Name.StartsWith("raw_",StringComparison.Ordinal)) continue;
            var selected=dst.SetUsageType(input.ID,vi,col.LineageID,DTSUsageType.UT_READONLY);
            foreach(IDTSExternalMetadataColumn100 external in input.ExternalMetadataColumnCollection)
                if(external.Name==col.Name) dst.MapInputColumn(input.ID,selected.ID,external.ID);
        }
        // Keep error records traceable by file and CSV ordinal, without copying raw values to logs.
        var reject=Component(pipe,"DTSTransform.DerivedColumn.8","Rejected row metadata");
        pipe.PathCollection.New().AttachPathAndPropagateNotifications(derive.OutputCollection[1],reject.InputCollection[0]);
        SelectInputs(reject,new[]{"raw_SourceRowNumber","ErrorCode","ErrorColumn"});
        var rejectWrapper=reject.Instantiate(); var rejectOutput=reject.OutputCollection[0];
        string[] rejectNames={"RejectBatchID","RejectSourceFileID","RejectSourceRowNumber","RejectErrorCode","RejectErrorMessage"};
        string[] rejectExpressions={"@[User::BatchID]","@[User::SourceFileID]","(DT_I8)(DT_R8)[raw_SourceRowNumber]",
            "(DT_STR,50,1252)[ErrorCode]","\"Derived Column conversion failed; SSIS ErrorColumn=\" + (DT_WSTR,20)[ErrorColumn]"};
        for(int i=0;i<rejectNames.Length;i++) {
            var col=rejectWrapper.InsertOutputColumnAt(rejectOutput.ID,rejectOutput.OutputColumnCollection.Count,rejectNames[i],"");
            if(i==1) col.SetDataTypeProperties(DataType.DT_I4,0,0,0,0);
            else if(i<3) col.SetDataTypeProperties(DataType.DT_I8,0,0,0,0);
            else if(i==3) col.SetDataTypeProperties(DataType.DT_STR,50,0,0,1252);
            else col.SetDataTypeProperties(DataType.DT_WSTR,1000,0,0,0);
            rejectWrapper.SetOutputColumnProperty(rejectOutput.ID,col.ID,"Expression",rejectExpressions[i]);
        }
        var rejectCount=Component(pipe,"DTSTransform.RowCount.8","Count rejected records");
        rejectCount.Instantiate().SetComponentProperty("VariableName","User::RowsRejected"); Connect(pipe,reject,rejectCount);
        var rejectDestination=Component(pipe,"DTSAdapter.OLEDBDestination.8","Audit rejected records");
        var rejectDest=rejectDestination.Instantiate(); rejectDest.SetComponentProperty("AccessMode",3);
        rejectDest.SetComponentProperty("OpenRowset","ctl.RejectedRow");
        rejectDest.SetComponentProperty("FastLoadOptions","CHECK_CONSTRAINTS");
        rejectDestination.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(sql);
        rejectDestination.RuntimeConnectionCollection[0].ConnectionManagerID=sql.ID;
        rejectDest.AcquireConnections(null); rejectDest.ReinitializeMetaData(); rejectDest.ReleaseConnections();
        Connect(pipe,rejectCount,rejectDestination);
        var rejectInput=rejectDestination.InputCollection[0]; var rejectVirtual=rejectInput.GetVirtualInput();
        foreach(IDTSVirtualInputColumn100 col in rejectVirtual.VirtualInputColumnCollection) {
            if(!rejectNames.Contains(col.Name)) continue;
            var selected=rejectDest.SetUsageType(rejectInput.ID,rejectVirtual,col.LineageID,DTSUsageType.UT_READONLY);
            string targetColumn=col.Name.Substring("Reject".Length);
            foreach(IDTSExternalMetadataColumn100 external in rejectInput.ExternalMetadataColumnCollection)
                if(external.Name==targetColumn) rejectDest.MapInputColumn(rejectInput.ID,selected.ID,external.ID);
        }
        var end=SqlTask(p.Executables,"03 Reconcile committed rows and finish audit",
            "SET NOCOUNT ON; DECLARE @F BIGINT=?,@B BIGINT=?,@Read BIGINT=?,@Rejected BIGINT=?,@Actual BIGINT; "
            + "SELECT @Actual=COUNT_BIG(*) FROM "+target+" WHERE BatchID=@B; "
            + "IF @Actual+@Rejected<>@Read THROW 51402,'Parsed, committed and rejected row counts do not match.',1; "
            + "IF @Rejected>0 BEGIN EXEC ctl.usp_EndFileLoad @FileLoadID=@F,@LoadStatus='FAILED',@RowsRead=@Read,"
            + "@RowsAccepted=@Actual,@RowsRejected=@Rejected; THROW 51405,'Conversion rejected records; inspect ctl.RejectedRow.',1; END; "
            + "EXEC ctl.usp_EndFileLoad @FileLoadID=@F,@LoadStatus='SUCCEEDED',@RowsRead=@Read,"
            + "@RowsAccepted=@Actual,@RowsRejected=0;",sql,new[]{"FileLoadID","BatchID","RowsRead","RowsRejected"});
        Success(p,start,data); Success(p,data,end);
        var failureAudit=SqlTask(p.Executables,"04 Finalize failed audit after pipeline counters settle",
            "SET NOCOUNT ON; DECLARE @F BIGINT=?,@B BIGINT=?,@Read BIGINT=?,@Actual BIGINT; "
            + "IF EXISTS(SELECT 1 FROM ctl.ETLFileLoad WHERE FileLoadID=@F AND LoadStatus='RUNNING') BEGIN "
            + "SELECT @Actual=COUNT_BIG(*) FROM "+target+" WHERE BatchID=@B; "
            + "IF @Read<@Actual SET @Read=@Actual; DECLARE @Rejected BIGINT=@Read-@Actual; "
            + "EXEC ctl.usp_EndFileLoad @FileLoadID=@F,@LoadStatus='FAILED',@RowsRead=@Read,"
            + "@RowsAccepted=@Actual,@RowsRejected=@Rejected; END; "
            + "THROW 51406,'File load failed. Inspect source row numbers, audit and SSIS diagnostics.',1;",sql,new[]{"FileLoadID","BatchID","RowsRead"});
        var dataFailure=p.PrecedenceConstraints.Add(data,failureAudit); dataFailure.Value=DTSExecResult.Failure; dataFailure.LogicalAnd=false;
        var endFailure=p.PrecedenceConstraints.Add(end,failureAudit); endFailure.Value=DTSExecResult.Failure; endFailure.LogicalAnd=false;
        flat.SetExpression("ConnectionString","@[User::PreparedRoot] + \"\\\\"+file+"\"");
        Parameterize(sql);
        source.ValidateExternalMetadata=false; dest.ValidateExternalMetadata=false; rejectDestination.ValidateExternalMetadata=false;
        new Application().SaveToXml(Path.Combine(project,p.Name+".dtsx"),p,null);
        Console.WriteLine("BUILT "+p.Name);
    }
    static void BuildNds(string project,string server) {
        var p=NewPackage("04_Load_Validate_NDS"); var cm=SqlManager(p,server);
        string[] stagingTables={"Application","PreviousApplication","BureauCredit","BureauBalance","InstallmentPayment","POSCashBalance","CreditCardBalance"};
        string complete=String.Join(" OR ",stagingTables.Select(t=>"NOT EXISTS(SELECT 1 FROM stg."+Q(t)+" WHERE BatchID=@B)"));
        string gate="IF NOT EXISTS(SELECT 1 FROM ctl.ETLBatch WHERE BatchID=@B AND BatchStatus='RUNNING') "
            + "THROW 51407,'Supply the shared RUNNING integration batch.',1; IF "+complete
            + " THROW 51408,'All seven staging tables are required before NDS. Obtain Application and Payment History inputs first.',1; "
            + "IF (SELECT COUNT(DISTINCT s.FileName) FROM ctl.ETLFileLoad f JOIN ctl.SourceFile s ON s.SourceFileID=f.SourceFileID "
            + "WHERE f.BatchID=@B AND f.LoadStatus='SUCCEEDED' AND f.RowsRejected=0 AND f.RowsRead=f.RowsAccepted "
            + "AND s.FileName IN (N'application_train.csv',N'application_test.csv',N'previous_application.csv',N'bureau.csv',N'bureau_balance.csv',"
            + "N'POS_CASH_balance.csv',N'installments_payments.csv',N'credit_card_balance.csv'))<>8 "
            + "THROW 51409,'Eight successful per-file audits are required before NDS.',1; ";
        var stg=SqlTask(p.Executables,"01 Validate all seven staging inputs",
            "SET NOCOUNT ON; DECLARE @B BIGINT=?; "+gate+"EXEC ctl.usp_ValidateHomeCreditStaging @BatchID=@B; "
            + "IF EXISTS(SELECT 1 FROM ctl.DataQualityResult WHERE BatchID=@B AND TestCode LIKE 'STG[_]%' AND TestStatus='FAIL') "
            + "THROW 51403,'Staging validation has FAIL. NDS will not run.',1;",cm,new[]{"BatchID"});
        var load=SqlTask(p.Executables,"02 Load NDS without replacing existing data",
            "EXEC etl.usp_LoadNDS @BatchID=?,@ConfirmReplace=0;",cm,new[]{"BatchID"});
        var test=SqlTask(p.Executables,"03 Persist NDS validation and enforce PASS",
            "SET NOCOUNT ON; DECLARE @B BIGINT=?; EXEC etl.usp_ValidateNDS @BatchID=@B,@PersistResults=1; "
            + "IF EXISTS(SELECT 1 FROM ctl.DataQualityResult WHERE BatchID=@B AND TestCode LIKE 'NDS[_]%' AND TestStatus='FAIL') "
            + "THROW 51404,'NDS validation has FAIL.',1;",cm,new[]{"BatchID"});
        Success(p,stg,load); Success(p,load,test); Parameterize(cm);
        new Application().SaveToXml(Path.Combine(project,p.Name+".dtsx"),p,null);
        Console.WriteLine("BUILT "+p.Name);
    }
    static int Run(string[] args) {
        var app=new Application(); var events=new Events();
        if(args[0]=="expressions") {
            foreach(string line in File.ReadAllLines(args[2])) {
                var parts=line.Split(new[]{'\t'},2);
                try {
                    var evaluator=new Microsoft.SqlServer.Dts.Runtime.Wrapper.ExpressionEvaluatorClass();
                    evaluator.Expression=parts[1]; object value;
                    evaluator.Evaluate(null,out value,false);
                    Console.WriteLine("PASS | "+parts[0]);
                } catch(Exception ex) { Console.WriteLine("FAIL | "+parts[0]+" | "+ex.Message); }
            }
            return 0;
        }
        if(args[0]=="build") {
            Directory.CreateDirectory(args[2]);
            BuildLoader(args[2],args[3],args[4],"previous_application.csv","PreviousApplication",1);
            BuildLoader(args[2],args[3],args[4],"bureau.csv","BureauCredit",2);
            BuildLoader(args[2],args[3],args[4],"bureau_balance.csv","BureauBalance",3);
            BuildNds(args[2],args[3]); return 0;
        }
        if(args[0]=="map") {
            var p=app.LoadPackage(args[2],events);
            foreach(Executable executable in p.Executables) {
                var host=executable as TaskHost;
                if(host==null || !(host.InnerObject is MainPipe)) continue;
                foreach(IDTSComponentMetaData100 component in ((MainPipe)host.InnerObject).ComponentMetaDataCollection)
                    foreach(IDTSOutput100 output in component.OutputCollection)
                        foreach(IDTSOutputColumn100 col in output.OutputColumnCollection)
                            Console.WriteLine(col.LineageID+" | "+component.Name+" | "+col.Name);
            }
            return 0;
        }
        if(args[0]=="run" || args[0]=="validate" || args[0]=="configure") {
            var p=app.LoadPackage(args[2],events);
            p.Variables["User::ServerInstance"].Value=args[3];
            p.Variables["User::BatchID"].Value=long.Parse(args[4],CultureInfo.InvariantCulture);
            p.Variables["User::PreparedRoot"].Value=args[5];
            if(args[0]=="configure") {
                app.SaveToXml(args[6],p,null);
                Console.WriteLine("CONFIGURED local designer package: "+Path.GetFileName(args[6]));
                return 0;
            }
            var result=args[0]=="run" ? p.Execute(null,null,events,null,null) : p.Validate(null,null,events,null);
            Console.WriteLine("PACKAGE "+p.Name+" | "+args[0]+" | "+result);
            return result==DTSExecResult.Success?0:1;
        }
        throw new ArgumentException("Expected build, validate, or run");
    }
    static int Main(string[] args) {
        if(args.Length<5) {Console.Error.WriteLine("Usage: build SSIS-root project server prepared-root; run SSIS-root package server batch prepared-root");return 2;}
        IntPtr handle=IntPtr.Zero; UIntPtr cookie=UIntPtr.Zero;
        try {
            var ctx=new ACTCTX(); ctx.cbSize=Marshal.SizeOf(typeof(ACTCTX));
            ctx.lpSource=Path.Combine(args[1],"SSIS160.manifest");
            handle=CreateActCtx(ref ctx);
            if(handle==new IntPtr(-1) || !ActivateActCtx(handle,out cookie))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            return Run(args);
        } catch(Exception ex) {Console.Error.WriteLine(ex.ToString());return 1;}
        finally {if(cookie!=UIntPtr.Zero) DeactivateActCtx(0,cookie);if(handle!=IntPtr.Zero && handle!=new IntPtr(-1)) ReleaseActCtx(handle);}
    }
}
