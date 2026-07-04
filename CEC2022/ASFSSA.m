
%%
function [fMin , bestX,Convergence_curve ] = ASFSSA(pop, M,c,d,dim,fobj  )
        
   P_percent = 0.2;    % The population size of producers accounts for "P_percent" percent of the total population size       


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pNum = round( pop *  P_percent );    % The population size of the producers   


lb= c.*ones( 1,dim );    % Lower limit/bounds/     a vector
ub= d.*ones( 1,dim );    % Upper limit/bounds/     a vector
%Initialization
     N = pop*dim;
     z(1)=rand;
    for k=1:N
         z(k+1) = mod(2 * z(k)+rand * (1/N),1);
        
    end
       for i = 1 : pop
         for j=1:dim
             G(i,j) = z((i-1)*dim+j+1); 
             x(i,j) = lb(j) + (ub(j) - lb(j)) * G(i,j); 
         end
          fit( i ) = fobj( x( i, : ) ) ;  
        end
                     

pFit = fit;                      
pX = x;                            % The individual's best position corresponding to the pFit
[ fMin, bestI ] = min( fit );      % fMin denotes the global optimum fitness value
bestX = x( bestI, : );             % bestX denotes the global optimum position corresponding to fMin
 

 % Start updating the solutions.

for t = 1 : M    
  
  [ ans, sortIndex ] = sort( pFit );% Sort.
  [fmax,B]=max( pFit );
   worse= x(B,:);  
         
   r2=rand(1);
   w = 0.2 * cos(pi/2 * (1-(t/M)));
if(r2<0.8)
    for i = 1 : pNum                                                   % Equation (3)
         r1=rand(1);
        x( sortIndex( i ), : ) = w * pX( sortIndex( i ), : )*exp(-(i)/(r1*M));
        x( sortIndex( i ), : ) = Bounds( x( sortIndex( i ), : ), lb, ub );
        fit( sortIndex( i ) ) = fobj( x( sortIndex( i ), : ) ); 
    end
else
   for i = 1 : pNum        
      x( sortIndex( i ), : ) = w * pX( sortIndex( i ), : )+randn(1)*ones(1,dim); 
      x( sortIndex( i ), : ) = Bounds( x( sortIndex( i ), : ), lb, ub );
      fit( sortIndex( i ) ) = fobj( x( sortIndex( i ), : ) ); 
      end
end
  [ ~, bestII ] = min( fit );      
  bestXX = x( bestII, : );          
 for i = 1 : pNum   
   x(sortIndex( i ), : ) = func_levy( x( sortIndex( i ), : ),bestXX  );  
   x( sortIndex( i ), : ) = Bounds( x( sortIndex( i ), : ), lb, ub );
   fit( sortIndex( i ) ) = fobj( x( sortIndex( i ), : ) );   
 end    
   [ ~, bestII ] = min( fit );      
   bestXX = x( bestII, : );
   for i = ( pNum + 1 ) : pop                     % Equation (4)
         k=5;
         A=floor(rand(1,dim)*2)*2-1;
         sz =[1,dim];
          L = unifrnd(-1,1,sz);
          xb(i,:) = bestXX+(abs(( pX( sortIndex( i ), : )-bestXX)))*(A'*(A*A')^(-1))* L;
          z = exp(k*cos(pi*(1-(t/M))));
          if( i>(pop/2))
              for j = 1:dim 
                 l = 0.01 .*( x( sortIndex(i),j) - bestXX(j));
                 x( sortIndex(i) , j )=exp(z*l) * cos(2*pi*l) * randn(1)*exp((worse(j)-pX( sortIndex( i ), j ))/(i)^2);
              end
          else
            for j = 1:dim 
              l = 0.01 .*( x( sortIndex(i),j) - bestXX(j));
              x( sortIndex(i) , j ) = xb(i,j) * exp(z*l) * cos(2*pi*l);
            end       
         end  
        x( sortIndex( i ), : ) = Bounds( x( sortIndex( i ), : ), lb, ub );
        fit( sortIndex( i ) ) = fobj( x( sortIndex( i ), : ) );    
   end
  c=randperm(numel(sortIndex));
   b=sortIndex(c(1:20));
    for j =  1  : length(b)      % Equation (5)

        if( pFit( sortIndex( b(j) ) )>(fMin) )

            x( sortIndex( b(j) ), : )=bestX+(randn(1,dim)).*(abs(( pX( sortIndex( b(j) ), : ) -bestX)));

        else

            x( sortIndex( b(j) ), : ) =pX( sortIndex( b(j) ), : )+(2*rand(1)-1)*(abs(pX( sortIndex( b(j) ), : )-worse))/ ( pFit( sortIndex( b(j) ) )-fmax+1e-50);

        end
            x( sortIndex(b(j) ), : ) = Bounds( x( sortIndex(b(j) ), : ), lb, ub );
       
            fit( sortIndex( b(j) ) ) = fobj( x( sortIndex( b(j) ), : ) );
    end
    for i = 1 : pop 
        if ( fit( i ) < pFit( i ) )
            pFit( i ) = fit( i );
            pX( i, : ) = x( i, : );
        end
        
        if( pFit( i ) < fMin )
           fMin= pFit( i );
           bestX = pX( i, : );
        end
    end
  
    Convergence_curve(t)=fMin;
  
end


% Application of simple limits/bounds
function s = Bounds( s, Lb, Ub)
  % Apply the lower bound vector
  temp = s;
  I = temp < Lb;
  temp(I) = Lb(I);
  
  % Apply the upper bound vector 
  J = temp > Ub;
  temp(J) = Ub(J);
  % Update this new move 
  s = temp;

%---------------------------------------------------------------------------------------------------------------------------
