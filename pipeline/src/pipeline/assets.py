import dagster as dg


@dg.asset
def hello(context: dg.AssetExecutionContext) -> str:
    """Proves the code location loads and runs; replaced by real assets later."""
    context.log.info("hello from Terra Plantarum")
    return "hello"
