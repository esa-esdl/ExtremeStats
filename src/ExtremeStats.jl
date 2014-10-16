module ExtremeStats

using DataArrays
using DSP
using NetCDF

evapofrac_path="/Volumes/BGI/people/uweber/_data/2MM/EvapoFrac_FLuxcom/Data"
years     = 2007:2012
N_years   = length(years)
lat_range = [45, 55] 
lon_range = [0, 20]  
NpY=46
y=years[1]
lons=ncread(joinpath(evapofrac_path,"EvapoFrac.$(years[1]).nc"),"lon")
lats=ncread(joinpath(evapofrac_path,"EvapoFrac.$(years[1]).nc"),"lat")
lonstep=lons[2]-lons[1]
latstep=lats[2]-lats[1]

cmplon=lonstep>0 ? .> : .< 
cmplat=latstep>0 ? .> : .<
ilon_range=sort!([findfirst(cmplon(lons,lon_range[1])),findfirst(cmplon(lons,lon_range[2]-lonstep))])
ilat_range=sort!([findfirst(cmplat(lats,lat_range[1])),findfirst(cmplat(lats,lat_range[2]-latstep))])
nlon=ilon_range[2]-ilon_range[1]
nlat=ilat_range[2]-ilat_range[1]

x=rand(Float32,nlon,nlat,N_years*46);

#iyear=1
#for iyear in 1:N_years
#    println("$iyear")
#    x=Array(Float32,nlon,nlat,N_years*46)
#    x[:,:,((iyear-1)*NpY+1):iyear*NpY]=ncread(joinpath(evapofrac_path,"EvapoFrac.$(years[iyear]).nc"),"EvapoFrac",[ilon_range[1],ilat_range[1],1],[nlon,nlat,-1]);
#end

function getSeasStat(series,NY,NpY,msc,stdmsc)
    NY*NpY==length(series) || error("Length of series not good")
    for iday = 1:NpY
        s=zero(eltype(series))
        s2=zero(eltype(series))
        n=0
        for iyear=0:(NY-1)
            v=series[(iyear)*NpY+iday]
            if !isnan(v) 
                s2=s2+v*v
                s=s+v
                n=n+1
            end
        end
        msc[iday]=s/n
        stdmsc[iday]=sqrt(s2/n-s*s/(n*n))
    end
    msc,stdmsc
end
#testx=[sin(linspace(0,2*pi,46)),2*sin(linspace(0,2*pi,46))]
#msc,stdmsc=getSeasStat(testx,2,46)
#@assert all(msc.==1.5*sin(linspace(0,2*pi,46)))
#@assert all([isapprox(abs(stdmsc[i]),abs(0.5*sin(linspace(0,2*pi,46))[i])) for i = 1:46])

function smooth_circular!(xin::Vector,xout::Vector,wl::Integer=9)
    mod(wl,2)==1 || error("Window length must be uneven")
    offs = div(wl,2)
    fwl=float64(wl)
    n=length(xin)
    awl=0
    s=0.0
    for i=(n-offs+1):n 
        if !isnan(xin[i]) 
            s=s+xin[i] 
            awl=awl+1 
        end 
    end
    for i=1:(offs+1) 
        if !isnan(xin[i]) 
            s=s+xin[i]; 
            awl=awl+1 
        end 
    end
    #Start main loop
    for i=1:offs
        xout[i]=s/awl
        if !isnan(xin[n-offs+i])
            s=s-xin[n-offs+i]
            awl=awl-1
        end
        if !isnan(xin[offs+1+i])
            s=s+xin[offs+1+i]
            awl=awl+1
        end
    end
    for i=(offs+1):(n-offs-1)
        xout[i]=s/awl
        if !isnan(xin[i-offs])
            s=s-xin[i-offs]
            awl=awl-1
        end
        if !isnan(xin[offs+1+i])
            s=s+xin[offs+1+i]
            awl=awl+1
        end
    end
    for i=(n-offs):n
        xout[i]=s/awl
        if !isnan(xin[i-offs])
            s=s-xin[i-offs]
            awl=awl-1
        end
        if !isnan(xin[i-n+offs+1])
            s=s+xin[i-n+offs+1]
            awl=awl+1
        end
    end
end

function anomalies(series::SubArray,msc,stdmsc,smsc,sstdmsc,series_anomaly)  
  # length of time series
  N    = length(series)  
  NpY  = 46
  filt = 9
    
  # devide length of time series by samples/year -> nr years
  NY=ifloor(N/NpY)
  # mean seasonal cycle
    getSeasStat(series,NY,NpY,msc,stdmsc) 
  # smooth MAC
    smooth_circular!(msc, smsc, 9)
    smooth_circular!(stdmsc, sstdmsc, 9)
  # deseasoanlized time series, difference of time series and mac
    for iyear=1:NY,iday=1:NpY     
        series_anomaly[(iyear-1)*NpY+iday]  = (series[(iyear-1)*NpY+iday] - smsc[iday])/sstdmsc[iday]
    end
  #return(series_anomaly) 
end

N=10
x=rand(N)
x[8:10]=NaN
println(select(x,9))
println(sort(x))
#@time quantile(x,0.05)

mapreduce(isnan,+,x)

anom=similar(x)
msc    = Array(Float64,NpY) #Allocate once
stdmsc = Array(Float64,NpY) #Allocate once
smsc    = Array(Float64,NpY) #Allocate once
sstdmsc = Array(Float64,NpY) #Allocate once
anomar=similar(x)
@time begin
for lon in 1:nlon, lat in 1:nlat
    anomalies(sub(x,lon,lat,:),msc,stdmsc,smsc,sstdmsc,sub(anomar,lon,lat,:))
    #println("$lon $lat")
end 
end

end # module
