#
#      Productmanifold – the manifold generated by the product of manifolds.
#
# Manopt.jl, R. Bergmann, 2018-06-26
import Base: exp, log, show

export ProductManifold, ProdMPoint, ProdTVector
export distance, dot, exp, log, manifoldDimension, norm, parallelTransport
export show, getValue

struct ProductManifold <: Manifold
  name::String
  manifolds::Array{Manifold}
  dimension::Int
  abbreviation::String
  ProductManifold(mv::Array{Manifold}) = new("ProductManifold",
    mv,prod(manifoldDimension.(mv)),string("Prod(",join([m.abbreviation for m in mv],", "),")") )
end

struct ProdMPoint <: MPoint
  value::Array{MPoint}
  ProdMPoint(v::Array{MPoint}) = new(v)
end
getValue(x::ProdMPoint) = x.value

struct ProdTVector <: TVector
  value::Array{TVector}
  ProdTVector(value::Array{TVector}) = new(value);
end
getValue(ξ::ProdTVector) = ξ.value
# Functions
# ---
addNoise(M::ProductManifold, x::ProdMPoint,σ) = ProdMPoint([addNoise.(M.manifolds, getValue(x)p.value,σ)])
distance(M::ProductManifold, x::ProdMPoint, y::ProdMPoint) = sqrt(sum( distance.(manifolds, getValue(p), getValue(q) ).^2 ))
dot(M::ProductManifold, x::ProdMPoint, ξ::ProdTVector, ν::ProdTVector) = sum(dot.(M.manifolds, getValue(x), getValue(ξ), getValue(ν) ));
exp(M::ProductManifold, x::ProdMPoint,ξ::ProdTVector,t::Number=1.0) = ProdMPoint( exp.(M.manifolds, getValue(p), getValue(ξ)) )
log(M::ProductManifold, x::ProdMPoint,y::ProdMPoint) = ProdTVector(log.(M.manifolds, getValue(x), getValue(y) ))
manifoldDimension(x::ProdMPoint) =  prod( manifoldDimension.( getValue(x) ) )
manifoldDimension(M::ProductManifold) = prod( manifoldDimension.(M.manifolds) )
norm(M::ProductManifold, ξ::ProdTVector) = sqrt( dot(M,ξ,ξ) )
# Display
show(io::IO, M::ProductManifold) = print(io,string("The Product Manifold of [ ",
    join([m.abbreviation for m in M.manifolds])," ]"))
show(io::IO, p::ProdMPoint) = print(io,string("ProdM[",join(repr.( getValue(p) ),", "),"]"))
show(io::IO, ξ::ProdTVector) = print(io,String("ProdMT[", join(repr.(ξ.value),", "),"]"))
