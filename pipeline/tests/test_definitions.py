import dagster as dg

from pipeline.assets import hello
from pipeline.definitions import defs


def test_hello_materializes():
    result = dg.materialize([hello])

    assert result.success
    assert result.output_for_node("hello") == "hello"


def test_definitions_load():
    dg.Definitions.validate_loadable(defs)
