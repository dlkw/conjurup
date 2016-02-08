import ceylon.language.meta.declaration {
    FunctionDeclaration,
    ClassDeclaration,
    ValueDeclaration
}
import ceylon.net.http {
    AbstractMethod,
    get
}

import de.dlkw.conjurup {
    ParamType,
    query
}
shared annotation PathAnnotation path(String ppath) => PathAnnotation(ppath);

"Annotates a method to define resource access in a RESTful API."
shared annotation ResourceAccessAnnotation resourceAccess(AbstractMethod method = get, String path = "") => ResourceAccessAnnotation(method, path);
shared annotation ParamAnnotation param(ParamType type = query, String name = "") => ParamAnnotation(type, name);
shared annotation ConsumesAnnotation consumes(String contentType) => ConsumesAnnotation(contentType);

shared final annotation class PathAnnotation(shared String ppath)
        satisfies OptionalAnnotation<PathAnnotation, ClassDeclaration>
        {}

shared final annotation class ResourceAccessAnnotation(shared AbstractMethod method, shared String path)
        satisfies OptionalAnnotation<ResourceAccessAnnotation, FunctionDeclaration>
        {}

shared final annotation class ParamAnnotation(shared ParamType type, shared String name)
        satisfies OptionalAnnotation<ParamAnnotation, ValueDeclaration>
        {}

shared final annotation class ConsumesAnnotation(shared String contentType)
        satisfies OptionalAnnotation<ConsumesAnnotation, ClassDeclaration|FunctionDeclaration>
        {}