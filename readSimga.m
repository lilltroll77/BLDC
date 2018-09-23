function out=readSigma(file)  
data= csvread(file);
out=interp1(data(:,1) , data(:,2)/max(data(:,2)) , data(1,1):data(end,1), 'previous');
   