variable "MCP_VERSION" {
  default = "1.3.1"
}

variable "DOCKERHUB_REPO" {
  default = "andreassag/inkscape-mcp"
}

variable "GHCR_REPO" {
  default = "ghcr.io/andreassag/inkscape-mcp"
}

variable "LEGACY_DOCKERHUB_REPO" {
  default = "andreassag/inkmcp"
}

variable "LEGACY_GHCR_REPO" {
  default = "ghcr.io/andreassag/inkmcp"
}

# Extracts major version component (e.g. "24" from "24.04")
function "major" {
  params = [ver]
  result = split(".", ver)[0]
}

# Formats tags for a given registry repository including MCP release version alongside Ubuntu version
function "format_tags" {
  params = [repo, ubuntu, mcp_version, is_latest]
  result = concat(
    ["${repo}:v${mcp_version}-ubuntu${ubuntu}"],
    ["${repo}:v${mcp_version}-ubuntu${major(ubuntu)}"],
    ["${repo}:v${mcp_version}"],
    ["${repo}:ubuntu${ubuntu}"],
    ["${repo}:ubuntu${major(ubuntu)}"],
    ["${repo}:ubuntu"],
    is_latest ? [
      "${repo}:latest"
    ] : []
  )
}

group "default" {
  targets = ["inkscape-mcp"]
}

target "inkscape-mcp" {
  name = "inkscape-mcp-ubuntu${replace(item.ubuntu, ".", "")}"

  # Matrix defining versions of Ubuntu to build
  matrix = {
    item = [
      {
        ubuntu = "24.04"
        latest = true
      }
    ]
  }

  context    = "."
  dockerfile = "Dockerfile"

  args = {
    UBUNTU_VERSION = item.ubuntu
    MCP_VERSION    = MCP_VERSION
  }

  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]

  tags = concat(
    format_tags(DOCKERHUB_REPO, item.ubuntu, MCP_VERSION, item.latest),
    format_tags(GHCR_REPO, item.ubuntu, MCP_VERSION, item.latest),
    format_tags(LEGACY_DOCKERHUB_REPO, item.ubuntu, MCP_VERSION, item.latest),
    format_tags(LEGACY_GHCR_REPO, item.ubuntu, MCP_VERSION, item.latest)
  )
}
