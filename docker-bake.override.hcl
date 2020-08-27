target "default" {
  inherits = ["shared"]
  args = {
    BUILD_TITLE = "Kibana"
    BUILD_DESCRIPTION = "A dubo image for Kibana"
  }
  tags = [
    "dubodubonduponey/kibana",
  ]
  platforms = ["linux/amd64"]
}
