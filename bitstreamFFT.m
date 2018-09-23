close all
%bin = de2bi(data(end-2^20+1:end),'left-msb');
%bitstream=double(bin(:)');

fs= 20e6;

%FFT=abs(fft(bitstream(end-2^20+1:end)));
hold off
close all
FFT=2*abs(fft(data/length(data)));
FFT(1)=0;
SUM=cumsum(FFT.^2);
SUM=SUM-SUM(8);
SUM(SUM<0)=0;
f=linspace(0 , fs , length(FFT));
semilogx(f , 20*log10(FFT) , f , 10*log10(SUM),'linewidth',2);
xlim([0 f(end)/2]);
grid on

hold on

N=3;
title('64X decimation with 512 taps FIR with simulated Space Vector Modulation');
%cicDecim = dsp.CICDecimator(64,1,N,'FixedPointDataType','Specify word lengths','SectionWordLengths', int64(32*ones(2*N,1)));
cicDecim = dsp.CICDecimator(64,1,N);
cicDecim.release;



len = 64*floor(length(data)/64);
%cic=cicDecim(data(1:len));
%cicDecim.SectionWordLengths=[32 32 32 32 32 32];
cic=step(cicDecim , data(1:len));
sinc3=cic(1:end)/64^N;
% %plot(sinc3)
% 
% sinc3=sinc3.*blackman(length(sinc3))/sqrt(((sum(blackman(length(sinc3)).^2 ) )/length(sinc3)));
% 
% FFT=2*abs(fft(sinc3/length(sinc3)));
% f=linspace(0 , 20e6/64 , length(FFT));
% FFT(1)=0;
% SUM=cumsum(FFT.^2);
% SUM=SUM-SUM(8);
% SUM(SUM<0)=0;
% semilogx(f(1:end/2) , 20*log10(FFT(1:end/2)) , f(1:end/2), 10*log10(SUM(1:end/2)));
% 
% 
win=Num;%chebwin(191);
fir=fftfilt(win,data);
cheb = fir(1:64:end)/sum(win);
cheb = cheb(12:end);
cheb=cheb.*blackman(length(cheb))/sqrt(((sum(blackman(length(cheb)).^2 ) )/length(cheb)));
FFT=2*abs(fft(cheb/length(cheb)));
f=linspace(0 , fs/64 , length(FFT));
FFT(1)=0;
SUM=cumsum(FFT.^2);
 SUM=SUM-SUM(8);
 SUM(SUM<0)=0;
semilogx(f(1:end/2) , 20*log10(FFT(1:end/2)) , f(1:end/2), 10*log10(SUM(1:end/2)));



hold off
%ylim([-160 0]);
xlabel('Frequency [Hz]');
ylabel('Level [dB]');
legend('FFT of raw data' , 'Power(f) of raw data' ,'FFT of decimated data (Blackman)' , 'Power(f) of decimated data');

return

dataS=double(data(1024:end-5))/64^3-0.5;
dataS=64/50*dataS(end-2^20+1:end);
win =blackman(length(dataS))/sqrt(((sum(blackman(length(dataS)).^2 ) )/length(dataS)));
FFT=2*abs(fft(dataS.*win./length(dataS)));
f=linspace(0 , fs/64 , length(FFT));
FFT(1:4)=0;
SUM=cumsum(FFT.^2);
 %SUM=SUM-SUM(8);
 %SUM(SUM<0)=0;
semilogx(f , 20*log10(FFT) , f, 0*10*log10(SUM)-160);
grid on
xlabel('Frequency [Hz]');
ylabel('Level [dB]');
legend('FFT of decimated data by XMOS' , 'Power(f) of XMOS decimated data');
xlim([f(4) f(end)/2]);
ylim([-220 0]);
str=sprintf('XMOS realtime decimation with 192 taps FIR filter (Sinc^3) FFTsize 2^2^0\n PI controller setpoint at 2.37A DC');
title(str);