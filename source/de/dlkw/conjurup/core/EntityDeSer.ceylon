import ceylon.json {
    Value, JsonObject= Object
}
import ceylon.language.meta.model {
    Type,
    Function
}

List<Ser<Nothing>> sers = [];
Ser<Entity>? serializer<Entity>()
{
    for (Ser<Nothing> s in sers) {
        if (is Ser<Entity> s) {
            return s;
        }
    }
    return null;
}

Ser<Anything>? seri<Entity>()
{
    value x = serializer<Entity>();
    if (is Null x) {
        return null;
    }
    return widen(x);
}

Ser<Anything>? dyn2(Type<Anything> ty)
{
    value s = `function seri`.apply<Ser<Anything>?, []>(ty);
    value y = s();
    return y;
}

Ser<Anything>? dynSerializer(Type<Anything> ty)
{
    value ser = `function serializer`.apply<Ser<Nothing>?, []>(ty);
    value y = ser();
    if (is Null y) {
        return null;
    }

    value dd = `function widen`;
    value xx = dd.apply<Ser<Anything>, [Ser<Nothing>]>(ty);
    //Function<Ser<Anything>, [Ser<Nothing>]> yy = widen<Nothing>;
    value a = widen(y);
    value b = xx(y);
    return a;
}

Ser<Anything> widen<T>(Ser<T> serializer)
{
    object widerSer satisfies Ser<Anything>
    {
        shared actual String ser(Anything val)
        {
            assert(is T val);
            return serializer.ser(val);
        }
    }
    return widerSer;
}

interface Ser<in Entity>
{
    shared formal String ser(Entity entity);
}


shared void abc0() {
    value g = serializer<Value>();
    print(g);
    if (exists g ) {
        print(g.ser(JsonObject({"a"->5})));
    }
    value h = serializer<Integer>();
    if (exists h) {
        print(h.ser(5));
    }
    value k = serializer<C>();
    if (exists k) {
        print(k.ser(C(5)));
    }
}

shared void abc2() {
    value g = dyn2(`Value`);
    print(g);
    if (exists g ) {
        print(g.ser(JsonObject({"a"->5})));
    }
    value h = dyn2(`Integer`);
    if (exists h) {
        print(h.ser(5));
    }
    value k = dyn2(`C`);
    if (exists k) {
        print(k.ser(C(5)));
    }
}

shared void abc1() {
    value g = dynSerializer(`Value`);
    print(g);
    if (exists g ) {
        print(g.ser(JsonObject({"a"->5})));
    }
    value h = dynSerializer(`Integer`);
    if (exists h) {
        print(h.ser(5));
    }
    Ser<Nothing> a;
    Ser<Integer|String> b = nothing;
    a = b;
}

class C(shared Integer a){}