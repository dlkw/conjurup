shared class PathAndMethodClashException([String+] messages)
        extends Exception(if (messages.shorterThan(2)) then messages.first else "The following clashes have been found:" + "\n\t".join(messages))
{}
