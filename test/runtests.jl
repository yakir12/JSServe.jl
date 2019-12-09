using Hyperscript, Markdown, Test
using JSServe, Observables
using JSServe: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, with_session
using JSServe.DOM

function test(session, req)

    s1 = Slider(1:100)
    s2 = Slider(1:100)
    b = Button("hi")
    t = TextField("Write!")
    linkjs(session, s1.value, s2.value)
    onjs(session, s1.value, js"(v)=> console.log(v)")
    on(println, t)
    return md = md"""
    # IS THIS REAL?

    My first slider: $(s1)

    My second slider: $(s2)

    Test: $(s1.value)

    The BUTTON: $(b)

    Type something for the list: $(t)

    some list $(t.value)
    """
end

app = Application(test, "127.0.0.1", 8081)

response = JSServe.HTTP.get("http://127.0.0.1:8081/")

@test response.status == 200

#TODO tests with chromium headless!
