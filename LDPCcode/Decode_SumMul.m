function [isSuc, errorframenum, errorbitnum] = Decode_SumMul( rcode, H_index, H_index_len, H_var, H_var_len, u, v, H_ldpc, LDPCEnCode )
%DECODE Summary of this function goes here
%   Detailed explanation goes here

%此函数没有实现循环迭代的功能，需要在外面写出来
%前两个参数是每一个校验方程包含的节点位置的索引
%后两个参数是每一个变量节点参与了那些校验方程


%rcode是接受到的1x2016的码字，应该是已经乘以4*snr的值
%     H_rec = zeros(1,2016); %用于保存1008次迭代的置信度数据
%     for ii = 1:1:1008
%         tmprec = zeros(1,8);
%         for jj = 1:1:H_index_len(ii,1)
%             tmp = 1;
%             for tt = 1:1:H_index_len(ii,1)
%                 if tt == jj
%                     continue;
%                 end
%                 tmp = tmp * tanh(rcode(1,H_index(ii,tt))/2);
%                 
%             end
%             tmpans = 2*atanh(tmp);
%             if tmpans > 100
%                 tmprec(1,jj) = 100;
%             elseif tmpans < -100
%                 tmprec(1,jj) = -100;
%             else
%                 tmprec(1,jj) = tmpans;
%             end
%             
%         end
%         %校验和置信度传递给变量置信度
%         for jj = 1:1:H_index_len(ii,1)
%             H_rec(1,H_index(ii,jj)) = H_rec(1,H_index(ii,jj)) + tmprec(1,jj);
%         end
%     end
%     retcode = rcode + H_rec;


%H_index, H_index_len, H_var, H_var_len, u, v
%H_index(i,j) 表示第i个校验节点参与的第j个节点的位置索引
%H_var(i,j)表示第i个变量节点参与的第j个校验方程的位置索引
    isSuc = 0;
    Vpan = zeros(1,2016);
    u0 = rcode; %u0表示初始的置信度
    for iter = 1:1:30%外层迭代30次
        for ii = 1:1:2016 %对每个变量节点进行计算
            %计算vi->j，只需要从H_var得到所有边的关系
            %u是一个1008x2016的矩阵，v是一个2016x1008的矩阵
            
            for jj = 1:1:H_var_len(ii,1)%每个变量节点连出来这么多线
                
                v(ii,H_var(ii,jj)) = u0(1,ii);
                for tt = 1:1:H_var_len(ii,1)%每个变量节点计算一个循环
                    if tt == jj %对应k!=j的条件
                        continue;
                    end
                    %v(ii,jj) = v(ii,jj) + u(H_var(ii,tt),findIndex(ii,H_var(ii,tt),H_index, H_index_len));
                    v(ii,H_var(ii,jj)) = v(ii,H_var(ii,jj)) + u(H_var(ii,tt),ii);
                end
                
            end
        
        end
        %第一部分结束，v(ii,jj)表示的是ii变量节点给第jj条索引的v值，注意校验节点对应的是H_var(ii,jj)
        %开始第二部分
        for ii = 1:1:1008
            for jj = 1:1:H_index_len(ii,1)
                tmp = 1;
                for tt = 1:1:H_index_len(ii,1)
                    if tt == jj
                        continue;
                    end
                    % k = H_index(ii,tt)
                    %tmp = tmp * tanh(v(H_index(ii,tt),find_varIndex(ii,H_index(ii,tt),H_var, H_var_len))/2);%H_index(ii,tt)表示第ii校验方程的第tt条边对应的变量节点的索引
                    tmp = tmp * tanh(v(H_index(ii,tt),ii)/2);
                end
                
                tmpans = 2*atanh(tmp);
                if tmpans > 100
                    u(ii,H_index(ii,jj)) = 100;
                elseif tmpans < -100
                    u(ii,H_index(ii,jj)) = -100;
                else
                    u(ii,H_index(ii,jj)) = tmpans;
                end
                
            end
        end
        
        %第三步，判决
        Vpan(1,:) = 0;
        for ii = 1:1:2016
            Vpan(1,ii) = u0(1,ii);
            for jj = 1:1:H_var_len(ii,1)
                Vpan(1,ii) = Vpan(1,ii) + u(H_var(ii,jj),ii);
            end
            if Vpan(1,ii)<0
                Vpan(1,ii) = 1;
            else
                Vpan(1,ii) = 0;
            end
        end
        
        %统计是否有错误
        judge = zeros(1,1008);
        if(mod(Vpan * H_ldpc',2) == judge)
            isSuc = 1; %正确了，跳出循环
            break;
        end        
    end
    
    if isSuc == 1 %没错误
        errorframenum = 0;
        errorbitnum = 0;
    else
        errorframenum = 1;
        errorbitnum = 0;
        for ii = 1009:1:2016
            if(Vpan(1,ii)~=LDPCEnCode(1,ii))
                errorbitnum = errorbitnum + 1;
            end
        end
    end
end

function index = findIndex(ii, num, H_index, H_index_len) 
    %对于第num个校验方程，寻找它连接的第ii个节点在它连接的所有节点中的编号
    index = -1;
    for tt = 1:1:H_index_len(num,1)
        if(H_index(num,tt)==ii)
            index = tt;
            break;
        end
    end
    if(index == -1)
        disp('没有找到H_index索引！')
    end
end

function index = find_varIndex(ii, num, H_var, H_var_len) 
    %对于第num个节点，寻找它连接的第ii个校验方程在它连接的所有校验方程中的编号
    index = -1;
    for tt = 1:1:H_var_len(num,1)
        if(H_var(num,tt)==ii)
            index = tt;
            break;
        end
    end
    if(index == -1)
        disp('没有找到H_var索引！')
    end
end