cmd=$0
for ARG in "$@"; do
    cmd="$cmd $ARG"
done
echo $cmd
$cmd &
