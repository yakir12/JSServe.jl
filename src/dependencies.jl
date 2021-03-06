# TODO, make sure that names are unique
"""
    dependency_path(paths...)

Path to serve downloaded dependencies
"""
dependency_path(paths...) = joinpath(@__DIR__, "..", "js_dependencies", paths...)

mediatype(asset::Asset) = asset.media_type

const server_proxy_url = Ref("")

function url(str::String)
    return server_proxy_url[] * str
end

function url(asset::Asset)
    if !isempty(asset.online_path)
        return asset.online_path
    else
        return url(AssetRegistry.register(asset.local_path))
    end
end

function Asset(online_path::String, onload::Union{Nothing, JSCode} = nothing)
    local_path = ""; real_online_path = ""
    if is_online(online_path)
        local_path = try
            #download(online_path, dependency_path(basename(online_path)))
            ""
        catch e
            @warn "Download for $online_path failed" exception=e
            local_path = ""
        end
        real_online_path = online_path
    else
        local_path = online_path
    end
    return Asset(Symbol(getextension(online_path)), real_online_path, local_path, onload)
end

"""
    getextension(path)
Get the file extension of the path.
The extension is defined to be the bit after the last dot, excluding any query
string.
# Examples
```julia-repl
julia> WebIO.getextension("foo.bar.js")
"js"
julia> WebIO.getextension("https://my-cdn.net/foo.bar.css?version=1")
"css"
```
"""
getextension(path) = lowercase(last(split(first(split(path, "?")), ".")))

"""
    islocal(path)
Determine whether or not the specified path is a local filesystem path (and not
a remote resource that is hosted on, for example, a CDN).
"""
is_online(path) = any(startswith.(path, ("//", "https://", "http://", "ftp://")))

function Dependency(name::Symbol, urls::AbstractVector)
    return Dependency(name, Asset.(urls), Dict{Symbol, JSCode}())
end

# With this, one can just put a dependency anywhere in the dom to get loaded
function jsrender(session::Session, x::Dependency)
    push!(session, x)
    return nothing
end

function jsrender(session::Session, asset::Asset)
    register_resource!(session, asset)
    return nothing
end

const JSCallLib = Asset("https://simondanisch.github.io/JSServe.jl/js_dependencies/core.js")

const JSCallLibLocal = Asset(dependency_path("core.js"))

const MsgPackLib = Asset("https://cdn.jsdelivr.net/gh/kawanet/msgpack-lite/dist/msgpack.min.js")

const MarkdownCSS = Asset(dependency_path("markdown.css"))
