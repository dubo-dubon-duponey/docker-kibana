package bake

command: {
  image: #Dubo & {
    args: {
      BUILD_TITLE: "Kibana"
      BUILD_DESCRIPTION: "A dubo image for Kibana based on \(args.DEBOOTSTRAP_SUITE) (\(args.DEBOOTSTRAP_DATE))"
    }

    platforms: [
      AMD64,
    ]
  }
}
