using Pkg
Pkg.activate(".")
using PlotlyJS
using Dash, DashHtmlComponents, DashCoreComponents

# Data for solving (dx/dt,dy/dt) = F(x,y), where F=field!
# (x0, y0) is the initial state and
# (tmin, tmax) the time interval for the solution
mutable struct ODEData
    field!::Function
    # Field function formulas
    dxdt::String
    dydt::String
    # Initial conditions
    x0::Float64
    y0::Float64
    # Time interval
    tmin::Float64
    tmax::Float64
end 

# Evaluates function in (x,y) from formula
function fxy(x, y, formula::String)
    ex = quote
        x = $x
        y = $y
        x + y
    end
    ex.args[6] = Meta.parse(formula)
    eval(ex)
end

# Parsing ODE data from field formulas
function parseODEData(dxdt, dydt, x0, y0, t0, t1)
    function field!(du, u, p, t)
        du[1] = fxy(u[1], u[2], dxdt)
        du[2] = fxy(u[1], u[2], dydt)
    end
    ODEData(field!, dxdt,dydt,x0, y0, t0, t1)
end


# Solves ODE explicitely using RK4
function solveODE(data::ODEData)
    f = data.field!
    n = 250 # steps count
    zero = [0.0;0.0]
    h = (data.tmax - data.tmin)/n # time step
    k1 = [0.0;0.0]
    k2 = [0.0;0.0]
    k3 = [0.0;0.0]
    k4 = [0.0;0.0]
    # Setting Initial conditions
    ps = [[0.0;0.0] for i = 1:(n+1)]
    ps[1] = [data.x0;data.y0]
    for i = 2:(n+1)
        p = ps[i-1] 
        f(k1,p,zero,0.0)
        f(k2,p + (h/2.0)*k1,zero,0.0)
        f(k3,p + (h/2.0)*k2,zero,0.0)
        f(k4,p + h*k3,zero,0.0)
        ps[i] = p + (h/6.0)*(k1 + 2*k2 +2*k3 + k4)
    end
    ps
end

# Gets the Plotly Scatter plot from the solution to the ODE
function trace(sol)
    x = [u[1] for u in sol]
    y = [u[2] for u in sol]
    scatter(;x=x, y=y, mode="lines", name="Solution")
end 

examples = Dict(
    "Spring"=>parseODEData("y","-x",3.0,0.0,0.0,2*3.1417),
    "DampedSpring" => parseODEData("y", "-x-y/3", 0.0, 4.0, 0.0, 30.0),
    "Pendulum"=>parseODEData("y", "-sin(x)", 3.0, 0.0, 0.0, 16),
    "Predator-Prey"=>parseODEData("x-x*y","x*y-y",2.0,3.0,0.0,8.0)
    )
  
default_example="Spring"
layout = Layout(;
    title = "", 
    xaxis_title="x",
    yaxis_title="y",
    xaxis_range=[-5, 5],
    yaxis_range=[-5, 5], width=550,height=500)
#
# Creation of Dash App starts here
#
#app = dash(external_stylesheets=["https://codepen.io/chriddyp/pen/bWLwgP.css"])

mathjax = "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.4/MathJax.js?config=TeX-MML-AM_CHTML"
app = dash(external_scripts=[mathjax])
#app = dash()
app.title = "DashODE"
# Utility fuction to retrieve inputs
function odeinput(label; value="")
    html_div(
    [dcc_input(id=label, type="text", value=value),html_span("  "*label)])
end

# Utility function to do n html breaks
function html_break(n)
    html_div([html_br() for i = 1:n])
end

odeoptions = [(label = k, value = k) for k in keys(examples)]

function ode_graph(sol)
    dcc_graph(id="odedash", figure=plot([trace(sol)], layout))
end

function ode_all_inputs()
    e = examples[default_example]
    [html_break(3),
    odeinput("dxdt",value=e.dxdt),
    odeinput("dydt",value=e.dydt),
    odeinput("x0",value=string(e.x0)),
    odeinput("y0",value=string(e.y0)),
    odeinput("time",value=string(e.tmax)),
    html_break(1),
    html_button("Solve", id="solve-button", n_clicks=0),
    html_break(1),
    html_h6("Load ODE"),
    html_div(style=Dict("max-width" => "200px"),
    dcc_dropdown(id="examples", options=odeoptions, value=default_example))]
end

title = "Solving Differential Equations Interactively"

description = raw"
This [Dash Julia](https://dash-julia.plotly.com/) application shows how to interactively solve 
[differential equations](https://en.wikipedia.org/wiki/File:Elmer-pump-heatequation.png) in two variables  `x` and `y` (with initial
condition given by `x0` and `y0` and time lapse equal to `time`). 


We will consider a few examples that arise when studying physical systems with one degree of freedom:

  - ***Spring*** (`x`=positon, `y`=velocity). This equation models a particle oscillating under the influence of a linear force (Hooke's law). 
  - ***Damped Spring***. We add to the above example a damping force (that depends linearly on velocity).
  - ***Pendulum*** (`x`=angle, `y`=angular velocity). This is a nonlinear equation modeling the oscillation of a pendulum.

You can load the above examples from the drop down menu below (don't forget to press the solve button after loading). You can 
modify these equations manually using the textual inputs, or you can create your own from scratch. 
"

# Setting the app's layout: ODE graph to the left and controls to the right. 

mathjax = html_script(type="text/javascript", async=true, id="MathJax-script", src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js")

html_header
 

app.layout = html_div(
    [html_center([html_h1("DashODE"),
    html_h2(title)]),
    dcc_markdown(description),
    html_div([
        html_div([ode_graph(solveODE(examples[default_example])),
        ], className="six columns"),
        html_div(ode_all_inputs(), className="six columns"),
    ], className="row")
])


# Update ODE data from dropdown
callback!(app,Output("dxdt","value"), Output("dydt","value"),
              Output("x0","value"), Output("y0","value"), Output("time", "value"),
              Input("examples", "value")) do value
    e = examples[value]
    return (e.dxdt, e.dydt, string(e.x0), string(e.y0), string(e.tmax))
end

# Update figure fro ODE data
callback!(
    app,
    Output("odedash", "figure"),
    Input("solve-button", "n_clicks"),
    State("x0", "value"),
    State("y0", "value"),
    State("dxdt", "value"),
    State("dydt", "value"),
    State("time", "value"),
) do clicks, x0, y0, dxdt, dydt, time
    x0f = parse(Float64,x0)  
    y0f = parse(Float64,y0)
    odedata = parseODEData(dxdt, dydt, x0f, y0f , 0.0, parse(Float64,time))
    sol = solveODE(odedata)
    p0G = scatter(;x=[x0f], y=[y0f], mode="markers",name="(x0,y0)")
    return plot([trace(sol),p0G], layout)
end
run_server(app, "0.0.0.0", debug=true)
