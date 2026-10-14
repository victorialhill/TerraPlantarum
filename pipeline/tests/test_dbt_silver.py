from pathlib import Path

import pytest
from dbt.cli.main import dbtRunner

PROJECT_DIR = Path(__file__).resolve().parents[1] / "dbt" / "silver"

PLACEHOLDER_LAKE_SETTINGS = {
    "DBT_ENV_SECRET_LAKEFS_ACCESS_KEY": "placeholder-access-key",
    "DBT_ENV_SECRET_LAKEFS_SECRET_KEY": "placeholder-secret-key",
    "LAKEFS_S3_ENDPOINT": "lakefs:8000",
    "LAKEFS_REPOSITORY": "placeholder-repository",
    "LAKEFS_BRANCH": "placeholder-branch",
}


@pytest.fixture
def lake_settings(monkeypatch):
    for name, value in PLACEHOLDER_LAKE_SETTINGS.items():
        monkeypatch.setenv(name, value)


def parse(tmp_path: Path):
    return dbtRunner().invoke(
        [
            "parse",
            "--project-dir",
            str(PROJECT_DIR),
            "--profiles-dir",
            str(PROJECT_DIR),
            "--target-path",
            str(tmp_path / "target"),
            "--log-path",
            str(tmp_path / "logs"),
        ]
    )


def test_silver_project_parses(lake_settings, tmp_path):
    result = parse(tmp_path)

    assert result.success, result.exception


def test_parse_fails_without_branch(lake_settings, monkeypatch, tmp_path):
    """The branch has no default, so a run that leaves it unset cannot write to main"""
    monkeypatch.delenv("LAKEFS_BRANCH")

    result = parse(tmp_path)

    assert not result.success
    assert "LAKEFS_BRANCH" in str(result.exception)
