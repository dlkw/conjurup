import ceylon.collection {
    MutableList,
    ArrayList,
    MutableMap,
    MutableSet,
    HashMap,
    HashSet
}

class CoProCombination0<Item>()
{
    MutableMap<String, MutableMap<String, Item>> cc = HashMap<String, MutableMap<String, Item>>();
    MutableMap<String, Item> catchAll = HashMap<String, Item>();

    shared void put([String+] consumes, [String+] produces, Item item)
    {
        if (exists cc = collidingCombo(consumes, produces)) {
            throw ConsumesProducesCollisionError<Item>(cc[0], cc[1], cc[2]);
        }

        consumes.each((c)
        {
            MutableMap<String, Item>? pp;

            if (c == "*/*") {
                pp = catchAll;
            }
            else {
                pp = cc[c];
            }

            if (exists pp) {
                for (p in produces) {
                    assert (is Null _ = pp.put(p, item));
                }
            }
            else {
                assert (is Null prev = cc.put(c, HashMap<String, Item>{entries = produces.map((p)=>p->item);}));
            }
        });
    }

    [String, String, Item]? collidingCombo([String+] consumes, [String+] produces)
    {
        for (consume in consumes) {
            value prod = cc.get(consume);
            if (exists prod) {
                for (p in produces) {
                    if (exists item = prod.get(p)) {
                        return [consume, p, item];
                    }
                }
            }
        }
        return null;
    }

    shared [String, Item]|UnsupportedMediaTypeError|NotAcceptableError match(String contentType, String accept)
    {
        value ct = cc.get(contentType);
        if ((ct else catchAll).empty) {
            return UnsupportedMediaTypeError();
        }

        String? match = if (exists ct) then bestMatch(ct.keys, accept) else null;
        if (is Null match) {
            String? matchWild = bestMatch(catchAll.keys, accept);
            if (is Null matchWild) {
                return NotAcceptableError();
            }
            assert (exists item = catchAll.get(matchWild));
            return [matchWild, item];
        }

        assert (exists item = ct?.get(match));
        return [match, item];
    }

    shared {String*} description(String(Item) info)
    {
        return cc.chain({"*/*"->catchAll}).flatMap((c->m)=>m.map((p->i)=>"``c``->``p``: ``info(i)``"));
    }
}

class UnsupportedMediaTypeError(){}
class NotAcceptableError(){}

class CoProCombination<Item>()
{
    MutableList<[[String+], [String+], Item]> combinations = ArrayList<[[String+], [String+], Item]>();

    shared void put([String+] consumes, [String+] produces, Item item)
    {
        if (exists cc = collidingCombo(consumes, produces)) {
            //throw ConsumesProducesCollisionError<Item>(cc[0], cc[1], cc[2]);
//            throw AssertionError("combi ``[consumes, produces, item]`` collides with ``cc``");
        }
        combinations.add([consumes, produces, item]);
        print(combinations);
    }

    [[String+], [String+], Item]? collidingCombo([String+] consumes, [String+] produces)
    {
        for (consume in consumes) {
            for (comb in combinations) {
                if (comb[0].contains(consume) && comb[1].containsAny(produces)) {
                    return comb;
                }
            }
        }
        return null;
    }
}

class ConsumesProducesCollisionError<Item>(consume, produce, item)
    extends Exception("Consumes/produces collision with ``consume``->``produce````if (exists item) then " (``item``)" else ""``")
{
    shared String consume;
    shared String produce;
    shared Item item;
}

shared void t2()
{
    value c = CoProCombination0<Anything>();
    c.put(["*/*"], ["*/*"], 1);
    c.put(["*/*"], ["text/plain"], 2);
    c.put(["*/*"], ["text/a", "text/b"], 3);
    c.put(["a", "b"], ["a", "b"], 4);
    c.put(["b", "c"], ["c", "d"], 5);
    c.put(["d", "b", "c"], ["e", "a"], 6);
}