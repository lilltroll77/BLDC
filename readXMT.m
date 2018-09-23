function data=readXMT(file)
   fid = fopen(file ,'r');
   txt= fscanf(fid,'%s');
   fclose(fid);
   
   I=strfind(txt,'User');
   disp("data imported");
   data=int32(zeros(length(I),1));
   for i=5:length(I)
    try
        data(i) = uint32(sscanf(txt(I(i)+6:I(i)+20) , '%d'));
    catch
        data=data(1:i);
    end
   end