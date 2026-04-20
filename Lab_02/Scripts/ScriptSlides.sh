rm -f gput.dat
for l in 'seq 16 100 1000'; do
	echo $l
	iperf3-darwin -c 192.168.1.3 -l $l -u --time 1|grep receiver | 
		tr -s ' ' |
		cut -d ' ' -f 7 >>gput.dat;
		sleep 1;
	done;
#cat gput.dat | awk '
#	BEGIN{max=0;min=99999999}
#		{x+=$0;y+=$0^2;if ($0<min){min=$0};if($0>max) {max=$0}}
#	END{print "avg=", x/NR,"\nmin=", min, "\nmax=", max, "\nstd=", sqrt(y/NR-(x/NR)^2)}' gnuplot <<
