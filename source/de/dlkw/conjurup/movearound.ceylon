import ceylon.language.meta.model {
	Class,
	UnionType,
	Type,
	ClassOrInterface
}

TypeConverters tc = TypeConverters();

[ClassOrInterface<Object>, Type<Object?>, Boolean] determineNullability(Type<Object?> _type)
{
    if (is UnionType<Object?> _type) {
        log.debug("union of ``_type.caseTypes``");
        variable Class<Object>? tt = null;
        variable Boolean nonNullFound = false;
        for (t in _type.caseTypes) {
            if (is Class<Object> t) {
                if (nonNullFound) {
                    throw Exception("only union of one class with Null supported");
                }
                tt = t;
                nonNullFound = true;
            }
            else if (!is Class<Null> t) {
                throw Exception("only union of class with Null supported");
            }
        }
        assert (exists ttt = tt);
        value x = [ttt, _type, true];
        return x;
    }
    else {
        assert (is ClassOrInterface<Object> _type);
        value x = [_type, _type, false]; 
        return x;
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

shared abstract class ParamType() of path | query | header  | cookie | form | body {}
shared object path extends ParamType() {string=>"path";}
shared object query extends ParamType() {string=>"query";}
shared object header extends ParamType() {string=>"header";}
shared object cookie extends ParamType() {string=>"cookie";}
shared object form extends ParamType() {string=>"form";}
shared object body extends ParamType() {string=>"body";}

shared {Element*} discard<Type, Element>({<Element|Type>*} input)
        => { for (el in input) if (!is Type el) el };
