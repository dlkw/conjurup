import de.dlkw.conjurup.core {
    Serializer,
    Deserializer
}
import com.fasterxml.jackson.databind {
    ObjectMapper,
    JsonNode
}
import com.kjetland.jackson.jsonSchema {
    JsonSchemaGenerator
}
import com.fasterxml.jackson.annotation {
    jsonProperty
}
import ceylon.interop.java {
    javaClass
}


shared object jacksonSer extends Serializer<Object>("application/json")
{
    value objectMapper = ObjectMapper();
    shared actual String serialize(Object entity) => objectMapper.writeValueAsString(entity);
}

shared object jacksonDeser satisfies Deserializer
{
    value objectMapper = ObjectMapper();
    shared actual O deserialize<O>(String input) given O satisfies Object => objectMapper.readValue(input, javaClass<O>());

    shared actual String mimetype => "application/json";
}

shared void x()
{
    value ow = OwnResponse(5, true);
    ObjectMapper om = ObjectMapper();
//    String s = om.writeValueAsString(ow);
    value xs = javaClass<OwnResponse>();
    value xd = `class OwnResponse`;

    JsonSchemaGenerator jsg = JsonSchemaGenerator(om);
    JsonNode schem = jsg.generateJsonSchema(javaClass<OwnResponse>());
    print(om.writeValueAsString(schem));

//    value u = om.readValue(s, xs);
//    print(u.string);
}

class OwnResponse(val, shared jsonProperty("uu") Boolean flag)
{
    shared jsonProperty("value") Integer? val;
    shared actual String string => "v:``val else "null"``, f:``flag else "null"``";
}
