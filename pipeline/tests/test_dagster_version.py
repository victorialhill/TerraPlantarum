import tomllib
from pathlib import Path

from packaging.version import Version

REPO_ROOT = Path(__file__).resolve().parents[2]


def locked_versions(lock_file: Path, package: str) -> Version:
    lock = tomllib.loads(lock_file.read_text(encoding="utf-8"))
    return Version(next(p["version"] for p in lock["package"] if p["name"] == package))


def test_host_dagster_is_not_older_than_pipeline():
    """The webserver and daemon may run a newer Dagster than this code location, never an older one

    Upgrade infra/dagster/uv.lock first, then pipeline/uv.lock.
    """
    host = locked_versions(REPO_ROOT / "infra" / "dagster" / "uv.lock", "dagster")
    code = locked_versions(REPO_ROOT / "pipeline" / "uv.lock", "dagster")

    assert host >= code, f"infra/dagster has Dagster {host}, older than pipeline's {code}"
