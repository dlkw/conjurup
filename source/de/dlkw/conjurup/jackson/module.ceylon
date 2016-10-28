"Default documentation for module `de.dlkw.conjurup.jackson`."
native ("jvm")
module de.dlkw.conjurup.jackson "0.0.1" {
    shared import de.dlkw.conjurup.core "0.2.0";

    import maven:"com.fasterxml.jackson.core:jackson-core" "2.8.4";
    import maven:"com.fasterxml.jackson.core:jackson-databind" "2.8.4";
    shared import maven:"com.fasterxml.jackson.core:jackson-annotations" "2.8.0";

    import maven:"com.kjetland:mbknor-jackson-jsonschema_2.11" "1.0.8";
    import ceylon.interop.java "1.3.0";
}
