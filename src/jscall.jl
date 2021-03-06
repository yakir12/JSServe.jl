abstract type AbstractJSObject end

"""
References objects stored in Javascript.
Maps the following expressions to actual calls on the Javascript side:
```julia
jso = JSObject(name, scope, typ)
# getfield:
x = jso.property # returns a new JSObject
# setfield
jso.property = "newval" # Works with JSObjects or Julia objects as newval
# call:
result = jso.func(args...) # works with julia objects and other JSObjects as args

# constructors are wrapped this way:
scene = jso.new.Scene() # same as in JS: scene = new jso.Scene()
```
"""
mutable struct JSObject <: AbstractJSObject
    # fields are private and not accessible via jsobject.field
    name::Symbol
    session::Session
    typ::Symbol
    # transporting the UUID allows us to have a uuid different from the objectid
    # which will help to better capture === equivalence on the js side.
    uuid::UInt

    function JSObject(name::Symbol, scope::Session, typ::Symbol)
        obj = new(name, scope, typ)
        setfield!(obj, :uuid, objectid(obj))
        # finalizer(remove_js_reference, obj)
        return obj
    end
end

struct JSGlobal <: AbstractJSObject
    name::Symbol
end

macro jsglobal(name)
    JSGlobal(Symbol(name))
end

"""
    JSObject(jso::JSObject, typ::Symbol)

Copy constructor with a new `typ`
"""
function JSObject(jso::JSObject, typ::Symbol)
    jsonew = JSObject(name(jso), session(jso), typ)
    # point new object to old one on the javascript side:
    evaljs(session(jso), js"put_on_heap($(uuidstr(jsonew)), $jso); undefined;")
    return jsonew
end

function JSObject(session::Session, name::Symbol)
    return JSObject(name, session, :variable)
end

# define accessors
for name in (:name, :session, :typ, :uuid)
    @eval $(name)(jso::JSObject) = getfield(jso, $(QuoteNode(name)))
end

"""
    uuidstr(jso::JSObject)

Returns the uuid as a string
"""
uuidstr(jso::JSObject) = string(uuid(jso))

"""
Overloading getproperty to allow the same semantic as Javascript.
Since there is no `new` keyword in Julia like in JS, we missuse
jsobject.new, to return an instance of jsobject with a new modifier.

So this Javascript:
```js
obj = new Module.Constructor()
```

Will translates to the following Julia code:
```Julia
obj = Module.new.Constructor()
```
"""
function Base.getproperty(jso::AbstractJSObject, field::Symbol)
    if field === :new
        # Create a new instance of jso, with the `new` modifier
        return JSObject(jso, :new)
    else
        result = JSObject(field, session(jso), typ(jso))
        send(
            session(jso),
            msg_type = JSGetIndex,
            object = jso,
            field = field,
            result = uuidstr(result),
        )
        return result
    end
end

function Base.setproperty!(jso::AbstractJSObject, field::Symbol, value)
    send(
        session(jso),
        msg_type = JSSetIndex,
        object = jso,
        value = value,
        field = field
    )
    return value
end

"""
    construct_arguments(args, keyword_arguments)
Constructs the arguments for a JS call.
Can only use either keyword arguments or positional arguments.
"""
function construct_arguments(args, keyword_arguments)
    if isempty(keyword_arguments)
        return args
    elseif isempty(args)
        # tojs isn't recursive bug:
        return keyword_arguments
    else
        # TODO: I'm not actually sure about this :D
        error("""
        Javascript only supports keyword arguments OR arguments.
        Found posititional arguments and keyword arguments
        """)
    end
end

"""
    jsobject(args...; kw_args...)

Call overload for JSObjects.
Only supports keyword arguments OR positional arguments.
"""
function jscall(jso::AbstractJSObject, args, kw_args)
    result = JSObject(:result, session(jso), :call)
    send(
        session(jso),
        msg_type = JSCall,
        func = jso,
        needs_new = getfield(jso, :typ) === :new,
        arguments = construct_arguments(args, kw_args),
        result = uuidstr(result)
    )
    return result
end

(jso::JSObject)(args...; kw_args...) = jscall(jso, args, kw_args)

struct JSModule <: AbstractJSObject
    session::Session
    mod::JSObject
    document::JSObject
    window::JSObject
    this::JSObject
    display_func # A function that gets called on show with the modules Scope
end

session(x::JSModule) = getfield(x, :session)
fuse(f, jso::JSObject) = fuse(f, session(jso))

"""
    jsobject(session::Session, js::JSCode, name = :object)

Returns the JSObject referencing the return value of `js`
"""
function jsobject(session::Session, js::JSCode, name = :object)
    result = JSObject(session, name)
    evaljs(session, js"""
        var object = $(js)
        put_on_heap($(uuidstr(result)), object);
    """)
    return result
end
