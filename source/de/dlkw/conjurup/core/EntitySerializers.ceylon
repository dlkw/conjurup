import ceylon.collection {
    HashMap,
    linked,
    MutableMap,
    MutableList,
    ArrayList,
    SortedMap,
    TreeMap
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
    Generic,
    UnionType
}

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

class SerializerRegistry()
{
    MutableMap<String, MutableMap<Type<Anything>, Serializer<Nothing>>> mimetypeMap = HashMap<String, MutableMap<Type<Anything>, Serializer<Nothing>>>();

    shared void putSerializer<Possible, UsedFor = Possible>(Serializer<Possible> serializer)
        given UsedFor satisfies Possible
    {
        log.debug("adding ``serializer.mimetype`` serializer `` `UsedFor` ``->``serializer``");

        assert (`UsedFor` != `Nothing`);

        if (is UnionType<> tArg = `UsedFor`) {
            for (comp in tArg.caseTypes) {
                value mDecl = `function putSerializer`;
                value method = mDecl.memberApply<SerializerRegistry, Anything, [Serializer<Possible>]>(`SerializerRegistry`, `Possible`, comp);
                value fun = method.bind(this);
                fun(serializer);
            }
            return;
        }

        log.debug("really adding ``serializer.mimetype`` serializer `` `UsedFor` ``->``serializer``");

        // use a tree map that sorts according to topological type hierarchy order
        value typeMap = putIfNotPresent(mimetypeMap, serializer.mimetype, ()=>TreeMap<Type<Anything>, Serializer<Nothing>>(typeHierarchyCompare));

        typeMap.put(`UsedFor`, serializer);
        log.debug("mimetypemap now ``mimetypeMap``");
    }

    shared Map<String, Serializer<Entity>>? collectSerializers<Entity>({String+} mimetypes)
    {
        String m = mimetypes.first;

        value typeMap = mimetypeMap[m];
        if (is Null typeMap) {
            return null;
        }

        value x = mimetypes.map((m)=>
                m->mimetypeMap[m]?.filterKeys((t)=>`Entity`.subtypeOf(t))
                        ?.first
                        ?.item);
        log.debug("checking ``x``");
        value y = x        .map((t->s)
                {
                    if (is Null s) {
                        // FIXME
                        throw AssertionError("No serializer for ``m`` to `` `Entity` `` found");
                    }
                    assert (is Serializer<Entity> s);
                    return t->s;
                });
        return map(y);
    }
}

Comparison typeHierarchyCompare(Type<Anything> t1, Type<Anything> t2)
    => if (t1.subtypeOf(t2)) then smaller
        else if (t1.supertypeOf(t2)) then larger
        else t1.string <=> t2.string;

shared void tls()
{
    MutableList<String> n = ArrayList<String>{};//elements={"q", "w", "aa", "s"};};
    for (i -> it in n.indexed) {
        print("``i``: ``it``");
        if (it == "a") {
            n.insert(i, "Z");
            break;
        }
    }
    else {
        n.add("Z");
    }
    print(n);

    alias B => Float;
    alias A => Number<B>;

    print(typeHierarchyCompare(`Integer`, `Integer&Float`));
}
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

object test1 extends Serializer<Object?>("")
{
    shared actual String serialize(Object? entity) => nothing;


}


class EntitySerializers3()
{
    SerializerRegistry().putSerializer(test1);
    variable Map<Type<Anything>, Map<String, Serializer<Nothing>>> tMap = map({});

    shared Serializer<Sub>? putSerializer<Argument, Sub = Argument>(Serializer<Argument> serializer)
    given Sub satisfies Argument
    {
        log.debug("adding ``serializer.mimetype`` serializer `` `Sub` ``->``serializer``");

        if (is UnionType<> tArg = `Sub`) {
            for (comp in tArg.caseTypes) {
                value mDecl = `function putSerializer`;
                value method = mDecl.memberApply<EntitySerializers3, Serializer<Nothing>?, [Serializer<Argument>]>(`EntitySerializers3`, `Argument`, comp);
                value fun = method.bind(this);
                fun(serializer);
            }
            return null;
        }

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

shared interface Deserializer
{
    shared formal String mimetype;
    shared formal O deserialize<out O>(String input)
            given O satisfies Object;
}

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
