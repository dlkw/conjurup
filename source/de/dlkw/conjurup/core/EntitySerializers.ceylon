import ceylon.collection {
    HashMap,
    linked,
    MutableMap,
    MutableList,
    ArrayList
}
import ceylon.json {
    Value,
    JsonObject=Object,
    JsonArray=Array
}
import ceylon.language.meta {
    type
}
import ceylon.language.meta.declaration {
    ClassOrInterfaceDeclaration,
    InterfaceDeclaration
}
import ceylon.language.meta.model {
    Type,
    ClassModel,
    InterfaceModel,
    Generic,
    UnionType
}

"A Serializer can serialize an instance of a given type (and all its subtypes)
 to a specific MIME type format."
shared abstract class Serializer<in Argument>(shared String mimetype)
{
    "Serialize the entity data to a String conforming to the MIME type `mimetype`."
    shared formal String serialize(Argument entity);
}

"Serializes any object to text/plain using the object's `string` property."
shared object toStringSerializer extends Serializer<Object>("text/plain")
{
    shared actual String serialize(Object entity) => entity.string;
}

"Serializes any generic JSON value to its JSON representation."
shared object simpleJsonSerializer extends Serializer<Value>("application/json")
{
    shared actual String serialize(Value jsonValue)
    {
        switch (jsonValue)
        case (is Integer|Float|Boolean|JsonObject|JsonArray) {
            return jsonValue.string;
        }
        case (is String) {
            return "\"``jsonValue``\"";
        }
        case (is Null) {
            return "null";
        }
    }
}

class SerializerRegistry()
{
    MutableMap<String, MutableList<Type<Anything>->Serializer<Nothing>>> mimetypeMap = HashMap<String, MutableList<Type<Anything>->Serializer<Nothing>>>();

    "Makes a serializer available for its mimetype and input type.

     The UsedFor type is the type that the serializer will be used for, even if it can
     serialize supertypes, too."
    shared void registerSerializer<UsedFor>(Serializer<UsedFor> serializer)
    {
        log.debug("adding ``serializer.mimetype`` serializer `` `UsedFor` ``->``serializer``");

        assert (`UsedFor` != `Nothing`);

        if (is UnionType<> tArg = `UsedFor`) {
            for (comp in tArg.caseTypes) {
                value mDecl = `function registerSerializer`;
                value method = mDecl.memberApply<SerializerRegistry, Anything, [Serializer<UsedFor>]>(`SerializerRegistry`, comp);
                value fun = method.bind(this);
                fun(serializer);
            }
            return;
        }

        log.debug("really adding ``serializer.mimetype`` serializer `` `UsedFor` ``->``serializer``");

        // use a list to insert the serializers according to input type topological type hierarchy order
        value typeList = putIfNotPresent(mimetypeMap, serializer.mimetype, ()=>ArrayList<Type<Anything>->Serializer<Nothing>>());

        // do inserting so that a subtype is always inserted before its supertypes
        // topological order according to type hierarchy graph
        for (i->e in typeList.indexed) {
            Comparison|Undefined partialComp = typeHierarchyCompare(`UsedFor`, e.key);
            if (partialComp == smaller) {
                typeList.insert(i, `UsedFor`->serializer);
                break;
            }
            else if (partialComp == equal) {
                typeList.set(i, `UsedFor`->serializer);
                break;
            }
        }
        else {
            typeList.add(`UsedFor`->serializer);

            log.debug("mimetypemap now ``mimetypeMap``");
        }
    }

    "Returns a map containing all registered Serializers serializing the given Entity type
     to all of the given MIME types. The keys in the map will be the MIME types, the items
     will be the Serializers.

     If no Serializer has been registered for a given MIME type and type, an AssertionError
     will be thrown."
    shared Map<String, Serializer<Entity>>? collectSerializers<Entity>({String+} mimetypes)
    {
        value x = mimetypes.map((m)=>m->mimetypeMap[m]?.find((t->s)=>`Entity`.subtypeOf(t))?.item);
        log.debug("checking ``x``");
        value y = x.map((t->s)
                {
                    if (is Null s) {
                        // FIXME do it like this on first not found?
                        throw AssertionError("No serializer for `` `Entity` `` to ``t`` found");
                    }
                    assert (is Serializer<Entity> s);
                    return t->s;
                });
        print(y);
        return map(y);
    }
}


abstract class Undefined() of undefined {}
object undefined extends Undefined(){}
"Defines a partial order for subtype relation."
Comparison|Undefined typeHierarchyCompare(Type<Anything> t1, Type<Anything> t2)
    => if (t1.subtypeOf(t2)) then smaller
        else if (t1.supertypeOf(t2)) then larger
        else undefined;

Item putIfNotPresent<Key, Item>(MutableMap<Key, Item> map, Key key, Item create())
    given Key satisfies Object
{
    Item? item = map[key];
    if (exists item) {
        return item;
    }
    Item newItem = create();
    map.put(key, newItem);
    return newItem;
}

class EntityDeserializers()
{
    variable value tMap = HashMap<Type<Anything>, HashMap<String, Deserializer>>(linked);

    shared Deserializer? putDeserializer<Argument>(Deserializer deserializer)
    {
        assert (`Argument` != `Nothing`);

        value sMap = tMap.get(`Argument`);
        if (is Null sMap) {
            value newMap = HashMap<String, Deserializer>{ entries = { deserializer.mimetype->deserializer };};
            log.debug("adding deserializer for type `` `Argument` ``");
            tMap.put(`Argument`, newMap);
            return null;
        }

        return sMap.put(deserializer.mimetype, deserializer);
    }

    shared Map<String, Deserializer>? selectDeserializer(Type<Anything> entityType)
    {
        return tMap.filter(
            (t->m) {
                //print("e: `` `Entity` ``");
                //print(t);
                //print(m);
            return t.supertypeOf(entityType);})
            .map(
            (t->m)=>m)
            .first;
    }

    shared actual String string => tMap.string;
}

shared interface Deserializer
{
    shared formal String mimetype;
    shared formal O deserialize<out O>(String input)
            given O satisfies Object;
}
