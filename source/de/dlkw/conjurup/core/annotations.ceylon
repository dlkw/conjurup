import ceylon.language.meta.declaration {
    FunctionDeclaration,
    ClassDeclaration,
    ValueDeclaration
}
import ceylon.http.common {
    AbstractMethod,
    get
}

shared annotation PathAnnotation path(String path) => PathAnnotation(path);

"Annotates a method to define resource access in a RESTful API."
shared annotation ResourceAccessAnnotation resourceAccess(AbstractMethod method = get, String path = "") => ResourceAccessAnnotation(method, path);
shared annotation ParamAnnotation param(ParamType type = query, String name = "") => ParamAnnotation(type, name);
shared annotation ConsumesAnnotation consumes([String+] contentType) => ConsumesAnnotation(contentType);
shared annotation ProducesAnnotation produces([String+] contentType) => ProducesAnnotation(contentType);

shared final annotation class PathAnnotation(shared String ppath)
        satisfies OptionalAnnotation<PathAnnotation, ClassDeclaration>
        {}

shared final annotation class ResourceAccessAnnotation(shared AbstractMethod method, shared String path)
        satisfies OptionalAnnotation<ResourceAccessAnnotation, FunctionDeclaration>
        {}

shared final annotation class ParamAnnotation(shared ParamType type, shared String name)
        satisfies OptionalAnnotation<ParamAnnotation, ValueDeclaration>
        {}

shared final annotation class ConsumesAnnotation(shared [String+] contentTypes)
        satisfies OptionalAnnotation<ConsumesAnnotation, ClassDeclaration|FunctionDeclaration>
        {}

shared final annotation class ProducesAnnotation(shared [String+] contentTypes)
        satisfies OptionalAnnotation<ProducesAnnotation, ClassDeclaration|FunctionDeclaration>
{}
