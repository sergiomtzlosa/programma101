# example application taken from Programma 101 user's manual
# enter p,q, compute n1=p+q, n2=p-q, n3=pq, n=n1+n2+n3,
# if n>0 then compute sqrt(n) else compute p/q
A V
C !
  S
B/^
  S
B ^
B/$
B +
A %
C &
B/$
B -
A %
C +
C &
B/$
B *
A %
C +
A %
 /V
B/$
B :
A %
  V
A/V
A #
A %
  V
