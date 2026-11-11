import csv
import tempfile
import unittest
from pathlib import Path

from prepare_source import prepare, typed_value


class PrepareSourceTests(unittest.TestCase):
    def test_storage_casts_keep_integer_precision_and_sentinels(self):
        self.assertEqual(typed_value("365243.0", "BIGINT"), "365243")
        self.assertEqual(typed_value("9223372036854775807", "BIGINT"), "9223372036854775807")
        self.assertEqual(typed_value("1.23456789015", "DECIMAL(28,10)"), "1.2345678902")
        self.assertEqual(typed_value("-1.23456789015", "DECIMAL(28,10)"), "-1.2345678902")
        self.assertEqual(typed_value("1.2e-5", "DECIMAL(28,10)"), "0.0000120000")
        self.assertEqual(typed_value("", "DECIMAL(28,10)"), "")
        with self.assertRaises(ValueError):
            typed_value("1.5", "BIGINT")

    def test_csv_records_and_values_survive_quotes_newlines_and_empty_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.csv"
            target = Path(directory) / "prepared.csv"
            values = [["123", 'comma, quote " and\nnewline', ""], ["456", "", "365243.0"]]
            with source.open("w", encoding="utf-8", newline="") as handle:
                csv.writer(handle).writerows([["id", "label", "amount"], *values])
            original = source.read_bytes()
            self.assertEqual(prepare(source, target)["rows"], 2)
            with target.open(encoding="utf-8", newline="") as handle:
                rows = list(csv.reader(handle))
            self.assertEqual(rows[1:], [[str(i), *v] for i, v in enumerate(values, 1)])
            self.assertEqual(source.read_bytes(), original)

    def test_row_limit_is_explicitly_labeled_sample(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.csv"
            target = Path(directory) / "prepared.csv"
            source.write_text("id\n1\n2\n", encoding="utf-8")
            result = prepare(source, target, 1)
            self.assertEqual((result["rows"], result["scope"]), (1, "sample"))

    def test_bad_record_does_not_replace_previous_prepared_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.csv"
            target = Path(directory) / "prepared.csv"
            source.write_text("id,name\n1,A,unexpected\n", encoding="utf-8")
            target.write_text("previous output", encoding="utf-8")
            with self.assertRaises(ValueError):
                prepare(source, target)
            self.assertEqual(target.read_text(encoding="utf-8"), "previous output")
            self.assertFalse(target.with_suffix(".csv.partial").exists())


if __name__ == "__main__":
    unittest.main()
