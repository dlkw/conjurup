import ceylon.collection {
    HashMap,
    linked
}
import ceylon.json {
    Value,
    JsonObject = Object,
    JsonArray = Array
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
    Generic
}

/*
class EntitySerializers()
{
    value registeredSerializers = ArrayList<Anything>();

    shared Serializer<Argument>? putSerializer<Argument, Sub = Argument>(Serializer<Argument> serializer)
        given Sub satisfies Argument
    {
        log.debug("adding ``serializer.mimetype`` serializer `` `Sub` ``->``serializer``");
        for (entry in registeredSerializers) {
            if (is TypedEntry<Sub> entry) {
                value type = entry.key;
                value map = entry.item;
            }
            assert (is HashMap<String, Serializer<Sub>> map);
            if (`Sub`.subtypeOf(type)) {
                assert (is Serializer<Argument> existing = (map of HashMap<String, Serializer<Sub>>).put(serializer.mimetype, serializer));
                print(registeredSerializers);
                return existing;
            }
        }
        value map = HashMap<String, Serializer<Sub>>{ entries = {serializer.mimetype->serializer}; };
        registeredSerializers.add(TypedEntry(`Sub`, map));
        print(registeredSerializers);
        return null;
    }
    putSerializer<Value, Value>(jacksonSer);

    shared Map<String, Serializer<Entity>>? selectSerializer<Entity>()
    {
        value typeSerializers = registeredSerializers.filter((e) => `Entity`.subtypeOf(e.key)).map((e) => e.item).first;
        if (is Null typeSerializers) {
            return null;
        }
        assert (is Map<String, Serializer<Entity>> typeSerializers);
        return typeSerializers;
    }
}
*/

shared abstract class Serializer<in Argument>(shared String mimetype)
{
    shared formal String serialize(Argument entity);
}

shared object simpleJsonSer extends Serializer<Value>("application/json")
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

//class TypedEntry<in T>(shared Type<T> key, shared Map<String, Serializer<T>> item){}

/*
class EntitySerializers2()
{
    value typePart = ArrayList<Type<Anything>>();
    value serializerPart = ArrayList<Map<String, Serializer<Nothing>>>();

    shared Serializer<Argument>? putSerializer<Argument, Sub = Argument>(Serializer<Argument> serializer)
    given Sub satisfies Argument
    {
        log.debug("adding ``serializer.mimetype`` serializer `` `Sub` ``->``serializer``");
        for (i->t in typePart.indexed) {
            if (is Sub t) {
                value type = entry.key;
                value map = entry.item;
            }
            assert (is HashMap<String, Serializer<Sub>> map);
            if (`Sub`.subtypeOf(type)) {
                assert (is Serializer<Argument> existing = (map of HashMap<String, Serializer<Sub>>).put(serializer.mimetype, serializer));
                print(registeredSerializers);
                return existing;
            }
        }
        value map = HashMap<String, Serializer<Sub>>{ entries = {serializer.mimetype->serializer}; };
        typePart.add(`Sub`);
        serializerPart.add(map);
        return null;
    }
    putSerializer<Value, Value>(jacksonSer);

    shared Map<String, Serializer<Entity>>? selectSerializer<Entity>()
    {
        value typeSerializers = registeredSerializers.filter((e) => `Entity`.subtypeOf(e.key)).map((e) => e.item).first;
        if (is Null typeSerializers) {
            return null;
        }
        assert (is Map<String, Serializer<Entity>> typeSerializers);
        return typeSerializers;
    }
}
*/

class EntitySerializers3()
{
    variable Map<Type<Anything>, Map<String, Serializer<Nothing>>> tMap = map({});

    shared Serializer<Sub>? putSerializer<Argument, Sub = Argument>(Serializer<Argument> serializer)
    given Sub satisfies Argument
    {
        log.debug("adding ``serializer.mimetype`` serializer `` `Sub` ``->``serializer``");
        value sMap = tMap.get(`Sub`);
        if (is Null sMap) {
            value newMap = map({ serializer.mimetype->serializer });
            log.debug("adding for subtype `` `Sub` ``");
            tMap = map<Type<Anything>, Map<String, Serializer<Nothing>>>({ `Sub`->newMap, *tMap.filter((t->m) { print("process ``t `` subtype of `` `Sub` ``?");
                print(if (t != `Sub`) then "keep" else "replace"); return t != `Sub`;}) });
            //tMap = map({`Sub`->newMap});
            log.debug("type map now is ``tMap``");
            return null;
        }

        assert (is Map<String,Serializer<Sub>> sMap);

        variable Serializer<Sub>? a = null;
        Serializer<Sub> xxx(Serializer<Sub> earlier, Serializer<Sub> later)
        {
            a = earlier;
            return later;
        }
        value nsMap = map({ serializer.mimetype->serializer, *sMap }, xxx);
        print("xxx ``tMap.map((t->m) => t)``");
        tMap = map<Type<Anything>, Map<String, Serializer<Nothing>>>({ `Sub`->nsMap, *tMap.filter((t->m) { print("process ``t `` subtype of `` `Sub` ``?");
            print(if (t != `Sub`) then "keep" else "replace"); return t != `Sub`;}) });
        print(tMap);
        print(tMap.size);
        return a;
    }
    if (exists x = putSerializer(simpleJsonSer)) {
        log.debug("replacing existing 1");
    }

    shared Map<String, Serializer<Entity>>? selectSerializer<Entity>()
    {
        value typeSerializers = tMap.filter(
            (t->m)
            =>
            `Entity`.subtypeOf(t))
            .map((t->m)
        => m)
            .first;
        if (is Null typeSerializers) {
            return null;
        }
        assert (is Map<String, Serializer<Entity>> typeSerializers);
        return typeSerializers;
    }
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

interface Converter<in From, out To>
given From satisfies Object
given To satisfies Object
{
    shared formal To convert(From input);
}

shared interface Deserializer
//satisfies Converter<String, To>
//given To satisfies Object
{
    shared formal String mimetype;
    shared formal O deserialize<out O>(String input)
            given O satisfies Object;
    /*
    shared default To deserialize(String src)
    {
        assert (is To obj = convert(src));
        return obj;
    }
    */
}


/*
interface TestDeserializer<To>
given To satisfies Object
{
    shared formal Out deserialize<out Out>(String input)
    given Out satisfies To;

    shared default TestDeserializer<Restrict> restricted<Restrict>()
    given Restrict satisfies To
            => object satisfies TestDeserializer<Restrict>
    {
        shared actual T deserialize<out T>(String input)
                given T satisfies Restrict
                => outer.deserialize(input);
    };
}
*/

Type<Anything> getTypeParam(Anything obj, Integer argPos, ClassOrInterfaceDeclaration tDecl)
{
    value z = type(obj);

    if (is InterfaceDeclaration tDecl) {
        if (exists found = checkInterfaces(z.satisfiedTypes, argPos, tDecl)) {
            return found;
        }
        throw AssertionError("does not satisfy ``tDecl``");
    }

    if (exists found = checkClass(z, argPos, tDecl)) {
        return found;
    }
    throw AssertionError("does not extend or satisfy ``tDecl``");
}

Type<Anything>? checkClass(ClassModel<Anything> classModel, Integer argPos, ClassOrInterfaceDeclaration tDecl) {
    value classDecl = classModel.declaration;
    if (classDecl == tDecl) {
        return typeArgument(classModel, argPos);
    }
    if (is InterfaceDeclaration tDecl) {
        if (exists found = checkInterfaces(classModel.satisfiedTypes, argPos, tDecl)) {
            return found;
        }
    }

    if (exists extendedType = classModel.extendedType) {
        return checkClass(extendedType, argPos, tDecl);
    }

    return null;
}

Type<Anything>? checkInterfaces(InterfaceModel<Anything>[] ifaces, Integer argPos,  InterfaceDeclaration tDecl) {
    for (interfaceModel in ifaces) {
        if (exists found = checkInterface(interfaceModel, argPos, tDecl)) {
            return found;
        }
    }
    return null;
}

Type<Anything>? checkInterface(InterfaceModel interfaceModel, Integer argPos, InterfaceDeclaration tDecl) {
    if (interfaceModel.declaration == tDecl) {
        return typeArgument(interfaceModel, argPos);
    }
    else {
        return checkInterfaces(interfaceModel.satisfiedTypes, argPos, tDecl);
    }
}

Type<Anything> typeArgument(Generic generic, Integer argPos)
{
    if (exists val = generic.typeArgumentList[argPos]) {
        return val;
    }
    else {
        throw AssertionError("no type parameter at index ``argPos``");
    }
}

shared void tt1()
{
    class A(){}
    class Aa() extends A(){}
    class Ab() extends A(){}
    class Aaa() extends Aa(){}
    class Aab() extends Aa(){}
    class B(){}
    class O<T>(shared actual String mimetype, String name) satisfies Deserializer
        given T satisfies Object
    {
        shared actual N deserialize<N>(String input)
                given N satisfies Object => nothing;

        shared actual String string => "deser ``mimetype`` to `` `T` `` (``name``)";
    }

    value dess = EntityDeserializers();
    print(dess);


    pr<Aaa>(dess, O<Aaa>("m1", "o5"));

    value xx = O<A>("m3", "xx");
    pr<A>(dess, xx);
    value xxx = xx;
    pr<A>(dess, xxx);

    pr<A>(dess, O<A>("m1", "o1"));
    pr<A>(dess, O<A>("m1", "o2"));
    pr<A>(dess, O<A>("m2", "o3"));
    pr<B>(dess, O<B>("m1", "o4"));

    print(dess.selectDeserializer(`A`));
    print(dess.selectDeserializer(`B`));
    print(dess.selectDeserializer(`Aa`));
    print(dess.selectDeserializer(`Aaa`));
    print(dess.selectDeserializer(`Aab`));
}

void pr<T>(EntityDeserializers dess, Deserializer d)
    //given T satisfies Object
{
    value cv = dess.putDeserializer<T>(d);
    print("``cv else "null"``: ``dess``");
    print("");
}

shared void testMap()
{
    value m1 = map({1->"a", 2->"b", 1->"c"});
    print(m1);

    function r(String earlier, String later) {
        return later;
    }
    value m2 = map<Integer, String>({1->"a", 2->"b", 1->"c"}, r);
    print(m2);
}
