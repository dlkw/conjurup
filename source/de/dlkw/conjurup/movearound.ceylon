import ceylon.language.meta {
    annotations
}
import ceylon.language.meta.declaration {
    ValueDeclaration
}
import ceylon.language.meta.model {
    Function,
    Interface,
    Class,
    UnionType,
    Type,
	ClassOrInterface
}

import de.dlkw.conjurup.annotations {
    ParamAnnotation
}

TypeConverters tc = TypeConverters();

[ClassOrInterface<Anything>, Boolean] determineDetailType(Type<> _type)
{
    if (is UnionType<> _type) {
        log.debug("union of ``_type.caseTypes``");
        variable Class<>? tt = null;
        variable Boolean nonNullFound = false;
        for (t in _type.caseTypes) {
            if (is Class<> t) {
                if (t != `Null`) {
                    if (nonNullFound) {
                        throw Exception("only union of class with Null supported");
                    }
                    tt = t;
                    nonNullFound = true;
                }
            }
            else {
                throw Exception("only union of class with Null supported");
            }
        }
        assert (exists ttt = tt);
        return [ttt, true];
    }
    else {
        assert (is ClassOrInterface<> _type);
        return [_type, false];
    }
}

<Object?|NamedConversionError>(String?) converterDecorated(converter, parameterName, paramType)
{
    <Object?|ConversionError>(String?) converter;
    String parameterName;
    ParamType paramType;

    return (String? input)
    {
        value converted = converter(input);
        if (is ConversionError converted) {
            return NamedConversionError(parameterName, paramType, converted);
        }
        else {
            return converted;
        }
    };
}

<Object?[]|NamedConversionError>({String*}) listConverterDecorated(converter, parameterName, paramType)
{
    <Object?[]|ListConversionError>({String*}) converter;
    String parameterName;
    ParamType paramType;

    return ({String*} input)
    {
        value converted = converter(input);
        if (is ListConversionError converted) {
            return NamedConversionError(parameterName, paramType, converted);
        }
        else {
            return converted;
        }
    };
}

shared abstract class ParamType() of path | query | header  | cookie | form {}
shared object path extends ParamType() {string=>"path";}
shared object query extends ParamType() {string=>"query";}
shared object header extends ParamType() {string=>"header";}
shared object cookie extends ParamType() {string=>"cookie";}
shared object form extends ParamType() {string=>"form";}

shared {Element*} discard<Type, Element>({<Element|Type>*} input)
        => { for (el in input) if (!is Type el) el };
