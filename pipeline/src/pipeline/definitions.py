import dagster as dg

from pipeline.assets import hello

defs = dg.Definitions(assets=[hello])
