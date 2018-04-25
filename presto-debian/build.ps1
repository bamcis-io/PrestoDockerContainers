Param(
	[Parameter(Position = 0, ValueFromPipeline = $true)]
	[ValidateNotNullOrEmpty()]
	[System.String]$Version = "0.198"
)

& docker build ../"presto-debian" -t "bamcis/presto-debian:$Version" --build-arg "PRESTO_VERSION=$Version"