#
# Some small helpfers to hande (the product manifold of) manifold-valued images,
# namely \(\mathcal M^{n,m}\) of an manifold-valued array M
#
export constructImageGraph

"""
    constructImageGraph(img,type) - construct the graph that can be used
        within the algorithms to model forward differences
  #Arguments
  * img – the manifold-valued (MPoint-entries) image
  * type – the type of graph_
  ** `forwardDifference` – generate the forward difference graph
 """
function constructImageGraph{T<:MPoint}(data::Array{T}, graphtype::String)::Array{Tuple}
  if graphtype == "firstOrderDifference"
    numdims = ndims(data)
    dims = size(data)
    newnumel = 0
    for i=1:numdims
      ithDiffs = 1
      for j=1:numdims
        if i==j
          ithDiffs = ithDiffs*(dims[j]-1)
        else
          ithDiffs = ithDiffs*dims[j]
        end
      end
      newnumel = newnumel + ithDiffs
    end
    edges = Array{Tuple{Int,Int}}(newnumel)
    # fill with differences
    n=1
    for i=1:numdims
      # generate forward differences along ith dimension
      for index in eachindex(data) #for each index (linear)
        ind = ind2sub(dims,index) # get index (sub)
        if ind[i] < dims[i]     # forward difference in ith direction possible
          ind2 = [ind...]       # extract into array
          ind2[i] = ind2[i] + 1 # generate neighbor
          edges[n] = (sub2ind(dims,ind...),sub2ind(dims,ind2...))
          n=n+1
        end
      end
    end
  elseif graphtype == "secondOrderDifference"
    numdims = ndims(data)
    dims = size(data)
    newnumel = 0
    for i=1:numdims
      ithDiffs = 1
      for j=1:numdims
        if i==j
          ithDiffs = ithDiffs*(dims[j]-2)
        else
          ithDiffs = ithDiffs*dims[j]
        end
      end
      newnumel = newnumel + ithDiffs
    end
    edges = Array{Tuple{Int,Int,Int}}(newnumel)
    # fill with differences
    n=1
    for i=1:numdims
      # generate forward differences along ith dimension
      for index in eachindex(data) #for each index (linear)
        ind = ind2sub(dims,index) # get index (sub)
        if (ind[i] < dims[i]) && (1<ind[i])     # left and right neighbot in ith direction within array
          ind2 = [ind...]       # extract into array
          ind2[i] = ind2[i] + 1 # generate neighbor
          ind3 = [ind...]       # extract into array
          ind3[i] = ind3[i] - 1 # generate neighbor
          edges[n] = (sub2ind(dims,ind3...),sub2ind(dims,ind...),sub2ind(dims,ind2...))
          n=n+1
        end
      end
    end
  else # end of type checks
      throw( ErrorException(" constructImageGraph – unknown graph type: $graphtype " ) )
  end
  return edges
end
