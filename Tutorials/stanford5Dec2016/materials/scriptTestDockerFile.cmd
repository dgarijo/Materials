docker build -t dgarijo/test:v1 -f c:/Users/dgarijo/Desktop/dockerTest/dockerFile .

cp canary_test.bam test/input.bam

docker run -v c:/Users/dgarijo/Desktop/dockerTest/test:/out dgarijo/test:v1 samtools sort -o /out/sorted.bam /out/input.bam

cp test/sorted.bam c:/Users/dgarijo/Desktop/dockerTest/bananen.bam

rm test/input.bam

rm test/sorted.bam
