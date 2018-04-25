Param(
	[Parameter(Position = 0, ValueFromPipeline = $true)]
	[ValidateNotNullOrEmpty()]
	[System.String]$Version = "0.198"
)

& docker build ../"presto-alpine" -t "bamcis/presto-alpine:$Version" --build-arg "PRESTO_VERSION=$Version"