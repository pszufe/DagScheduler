function plot_solution_log(dfloads::NamedTuple; kwargs...)
    plot_solution_log(DataFrame(dfloads); kwargs...)
end
function plot_solution_log(df::AbstractDataFrame; kwargs...)
    workers = sort!(unique(df.worker))
    tvals = zeros(maximum(workers))
    plt = bar(;orientation=:h, yticks=(1:length(workers), string.("W",workers) ), linewidth=0,yflip=true,color=:green,legend=nothing,ylim=(0.5,length(workers)+0.5),kwargs...)
    xlabel!(plt, "Time")
    dfc = deepcopy(df)
    while nrow(dfc) > 0
        rowslast = DataFrame([g[findmax(g.t_end)[2],:] for g in groupby(dfc, :worker)])
        tvals .= .0
        setindex!.(Ref(tvals),rowslast.t_end,rowslast.worker)
        bar!(plt, tvals[workers], orientation=:h, linewidth=0,yflip=true,color=:green)
        tvals .= .0
        setindex!.(Ref(tvals),rowslast.t_start,rowslast.worker)
        bar!(plt, tvals[workers], orientation=:h, linewidth=0.5,linecolor=:white,yflip=true,color=:white)
        annotate!.(Ref(plt),(rowslast.t_start .+ rowslast.t_end) ./ 2,  findfirst.( .==(rowslast.worker), Ref(workers)),  text.(string.("T",rowslast.i),9,rotation=0 ))
        dfc = dfc[ (.!)(dfc.i .∈ Ref(rowslast.i) ), : ]
    end
    plt
end


function plot_solution_report(g::Graphs.AbstractGraph, c::AbstractMatrix{<:Real}, γ::Union{AbstractMatrix{<:Real}, Dict{Tuple{Int,Int}, <:AbstractMatrix{<:Real}}}, times::AbstractVector{<:Real}, assignW::AbstractVector{<:Integer}, penalties::AbstractDict{Tuple{Int64, Int64}, <:Real}, dfloads::Union{NamedTuple,DataFrame})

    assign=zeros(Int,Graphs.nv(g), size(c,2))
    setindex!.(Ref(assign),1, 1:size(c,1), assignW)
    cio = IOBuffer()
    println(cio, "INPUTs")
    println(cio, "Tasks times:")
    pretty_table(cio, c, header=string.("W",1:size(c,2)), row_labels=string.("T",1:size(c,1)),tf=tf_unicode)
    edg1 = Tuple(collect(Graphs.edges(g))[1])
    println(cio, "Transfer costs $(edg1):")
    γ1 = typeof(γ) <: AbstractMatrix ? γ : γ[edg1]
    pretty_table(cio,rstrip.(lstrip.(string.(γ1),'0'),'0'), header=string.("W",1:size(γ1,2)), row_labels=string.("W",1:size(γ1,1)),tf=tf_unicode)
    println(cio, "SOLUTION")
    pretty_table(cio, replace.(string.(assign), "0"=>"."), header=string.("W",1:size(c,2)), row_labels=string.("T",1:size(c,1)),tf=tf_unicode)
    println(cio, "Selected data transfers:")
    i = 0
    for key in collect(keys(penalties))[values(penalties) .> eps()]
         i+=1
         print(cio, "T",key[1],"@W",assignW[key[1]],"⟶", "T",key[2],"@W",assignW[key[2]], " ",penalties[key], "   ")
         i % 1 == 0 && println(cio)
    end
    txt = String(take!(cio));
    txt = replace(txt, " "=>"\u00a0");
    lege = plot(;legend=false, size=(200,800), xlim=(0,1), ylim=(0,1),  border=:none)
    annotate!(lege, -0.1, 1, text(txt, 7, :left, :top, :black,:courier ))
    tasktimes = getindex.(Ref(c), 1:size(c,1), assignW)
    edgelabel = Dict(keys(penalties) .=> [v < 10eps() ? "" : "$v" for v in values(penalties)])
    gp1 = graphplot(g;names=string.("T",1:Graphs.nv(g),"@W",assignW, "\nS ", times, "\ntm:", tasktimes, "\nF ",(times .+ tasktimes) ), nodesize=0.055, size=(600,800),edgelabel=edgelabel)
    pl1 = plot_solution_log(dfloads; size=(800,200), legend=false)
    lay1 = @layout [grid(1,2, widths=[0.3,0.7]){0.8h};  a{0.2h}]
    plot(lege,gp1, pl1, layout=lay1 , size=(800,800))
end
