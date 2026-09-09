"""Offline checks for schema-loader safeguards; no database is contacted."""

import importlib.util
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch


spec = importlib.util.spec_from_file_location(
    "initialize_database",
    Path(__file__).resolve().parents[1] / "scripts" / "initialize_database.py",
)
loader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(loader)


class InitializeDatabaseTests(unittest.TestCase):
    def setUp(self):
        self.connection = MagicMock()
        self.connection.execute.return_value.fetchone.return_value = (False,)
        self.details = {"host": "example", "dbname": "metals", "sslmode": "require"}
        self.sql = "SELECT 'demo schema';"

    def test_fresh_database_loads_sql_in_transaction(self):
        with patch.object(loader.psycopg, "connect", return_value=self.connection):
            loader.initialize(self.details, "test-password", self.sql)
        self.connection.execute.assert_called_with(self.sql)
        self.connection.__exit__.assert_called_once_with(None, None, None)

    def test_existing_tables_are_not_reset_by_default(self):
        self.connection.execute.return_value.fetchone.return_value = (True,)
        with patch.object(loader.psycopg, "connect", return_value=self.connection):
            with self.assertRaisesRegex(RuntimeError, "already exist"):
                loader.initialize(self.details, "test-password", self.sql)
        self.assertEqual(self.connection.execute.call_count, 1)

    def test_explicit_reset_loads_sql(self):
        self.connection.execute.return_value.fetchone.return_value = (True,)
        with patch.object(loader.psycopg, "connect", return_value=self.connection):
            loader.initialize(self.details, "test-password", self.sql, reset=True)
        self.connection.execute.assert_called_with(self.sql)

    def test_workflow_preserves_complete_existing_database(self):
        self.connection.execute.return_value.fetchone.return_value = (4,)
        with patch.object(loader.psycopg, "connect", return_value=self.connection):
            loaded = loader.initialize(self.details, "test-password", self.sql, skip_existing=True)
        self.assertFalse(loaded)
        self.assertEqual(self.connection.execute.call_count, 1)

    def test_workflow_rejects_partial_schema_without_resetting_it(self):
        self.connection.execute.return_value.fetchone.return_value = (2,)
        with patch.object(loader.psycopg, "connect", return_value=self.connection):
            with self.assertRaisesRegex(RuntimeError, "already exist"):
                loader.initialize(self.details, "test-password", self.sql, skip_existing=True)
        self.assertEqual(self.connection.execute.call_count, 1)

    def test_connection_timeout_is_retried_before_loading(self):
        with patch.object(loader.psycopg, "connect", side_effect=[
            loader.psycopg.errors.ConnectionTimeout("simulated timeout"), self.connection
        ]) as connect, patch.object(loader.time, "sleep") as sleep:
            loader.initialize(self.details, "test-password", self.sql)
        self.assertEqual(connect.call_count, 2)
        sleep.assert_called_once_with(10)
        self.assertEqual(self.connection.execute.call_count, 2)

    def test_sql_failure_is_not_retried_and_exits_transaction_with_error(self):
        result = MagicMock()
        result.fetchone.return_value = (False,)
        failure = loader.psycopg.ProgrammingError("simulated SQL failure")
        self.connection.execute.side_effect = [result, failure]
        with patch.object(loader.psycopg, "connect", return_value=self.connection) as connect:
            with self.assertRaises(loader.psycopg.ProgrammingError):
                loader.initialize(self.details, "test-password", self.sql)
        connect.assert_called_once()
        self.assertIs(self.connection.__exit__.call_args.args[1], failure)


if __name__ == "__main__":
    unittest.main()
