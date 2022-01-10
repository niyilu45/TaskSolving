#!/bin/bash
# 1) Delete Useless Lines
# 2) Depart to blocks with TaskBegin and TaskEnd
# 3) In every block, find the [str]
# 4) If [str] exist, change str to array in 5), else depart blocks to many files in 6).
# 5) Copy this block by size of array, and assgin value of array. 
#     Do not deal with the second [str] in this block, go to 2)
# 6) Depart blocks to files.

MAXTOP=100 # max number of the stack
declare TOP=0 # top of the stack
STACKTEMP= # for pop temp
declare -a STACK

function Push() {
    if [ -z "$1" ]; then
        return
    fi
    while [ $# != 0 ] ; do
        if [ "$TOP" = $MAXTOP ]; then
            echo "Full of stack, push failed!"
            return
        fi
        let TOP++
        STACK[$TOP]="$1"
        #echo "--------------- Push: ${STACK[$TOP]}"
        shift # input paramters left shift, $# --
    done
    return
}
function Pop() {
    STACKTEMP= # clear this temp.
    if [ "$TOP" = "0" ]; then
        echo "empty of the stack, pop failed!"
        return
    fi
    STACKTEMP=${STACK[$TOP]}
    unset STACK[$TOP]
    let TOP--
    return
}
function ShowStack() {
    echo "@@ -------------STACK------------"
    local i
    for i in "${STACK[@]}"; do
        echo "@@ ""$i"
    done
    echo "@@ stack size = $TOP"
    echo "@@ ------------------------------"
    echo
}
function PrintStackToFile() {
    local file=$1
    local i
    for i in "${STACK[@]}"; do
        echo $i >> $file
    done
    echo >> $file
}

function DelNoneUseLines(){
    local tmpFile=$1
    local commentStartFlag=$2
    local commentEndFlag=$3
    # delete lines begin with % \s* means 0 to n blank
    sed -i '/^\s*\%/d' $tmpFile
    # delete lines in CommentBegin and CommentEnd
    sed -i "/${commentStartFlag}/,/${commentEndFlag}/d" $tmpFile
}
function GetStrInBrace(){
    local str=$1
    str=${str#*\{} && str=${str%\}*}
    echo $str
}
function ReplaceBrace() {
    local oriStr=$1
    local valToReplace=$2
    local outStr=""
    outStr=`echo ${oriStr/\{*\}/$2}`
    echo $outStr
}
function GetStrInBrackets(){
    local str=$1
    str=${str#*[} && str=${str%]*}
    echo $str
}
function ReplaceBracket() {
    local oriStr=$1
    local valToReplace=$2
    local outStr=""
    outStr=`echo ${oriStr/\[*\]$/$2}`
    echo $outStr
    exit
}
function GetDataSplit(){
    local str=$1
    local out= # set empty
    if [ `IsExistColon "$str"` -eq 1 ]; then
        out=`GetDataSplitColon "$str"`
    else
        out=`GetDataSplitComma "$str"`
    fi
    echo "$out"
}
function GetDataSplitColon(){
    local str=$1
    OLDIFS=$IFS && IFS=':'
    local array=($str)
    IFS=$OLDIFS
    local first=${array[0]}
    local intvl=${array[1]}
    local last=${array[2]}
    if [ ${#array[*]} -ne 3 ]; then
        echo "[Error]: $str should have 3 members!"
        exit
    fi
    local data=`seq $first $intvl $last`
    echo ${data[@]}
}
function GetDataSplitComma(){
    local str=$1
    OLDIFS=$IFS && IFS=','
    local array=($str)
    IFS=$OLDIFS
    echo ${array[@]}
}
function GetDataSplitWave(){
    local str=$1
    OLDIFS=$IFS && IFS='~'
    local array=($str)
    IFS=$OLDIFS
    echo ${array[@]}
}
function IsExistColon(){
    [[ "$1" == *:* ]] && echo 1 && return
    echo 0
}
function IsExistBrace() {
    [[ "$1" == *\{* ]] && echo 1 && return
    echo 0
}
function IsExistBracket() {
    [[ "$1" == *\[* ]] && echo 1 && return
    echo 0
}
function DepartTask() {
    local varLines="$1"
    local file="$2"
    if [ ! "$varLines" ]; then
        # you can do some function here.
        PrintStackToFile $file
        return
    fi
    local curLine=`echo "$varLines" | sed -n '1p'`
    local otherLines=`echo "$varLines" | sed -n '2,$p'`
    #echo "curLine: $curLine"
    if [[ `IsExistBracket "$curLine"` -eq 1 ]]; then
        local strInBrack=`GetStrInBrackets "$curLine"`
        local dataInBrack=`GetDataSplit "$strInBrack"`
        local i
        dataInBrack=($dataInBrack)
        for i in `seq 0 $[${#dataInBrack[*]}-1]`; do
            echo "I'm here!!!"
            modifiedLine=`ReplaceBracket "$curLine" ${dataInBrack[$i]} `
            Push "$modifiedLine"
            DepartTask "$otherLines" $file
            Pop
        done
    else
        Push "$curLine"
        DepartTask "$otherLines" $file
        Pop
    fi
    return
}
function DepartBind() {
    local varLines="$1"
    local file="$2"
    local lineCnt
    local bindCnt
    local bindStartFlag=BindBegin
    local bindEndFlag=BindEnd
    local beLines
    if [ ! "$varLines" ]; then
        # you can do some function here.
        PrintStackToFile $file
        return
    fi
    local solveLine= # set empty
    local curLine=`echo "$varLines" | sed -n '1p'`
    local otherLines=`echo "$varLines" | sed -n '2,$p'`
    if [[ "$curLine" == *${bindStartFlag}* ]]; then
        beLines=`echo "$otherLines" | cat -n | grep $bindEndFlag | awk '{print $1}'`
        beLines=($beLines)
        # check bind number
        local bindNum=`echo "$otherLines" | sed -n '1p' | grep -o '~' | wc -l` && let bindNum++
        for (( lineCnt=1; lineCnt<${beLines[0]}; lineCnt++ )); do
            solveLine=`echo "$otherLines" | sed -n "${lineCnt}p"`
            if [ `IsExistBrace "$solveLine"` -ne 1 ]; then
                echo "[Error] Bind areas should have brace!"
                exit
            fi
            local bindNumTmp=`echo "$solveLine" | grep -o '~' | wc -l` && let bindNumTmp++
            if [ $bindNum -ne $bindNumTmp ]; then
                echo "[Error] Bind number shoud be same!"
                exit
            fi
        done
        for (( bindCnt=0; bindCnt<$bindNum; bindCnt++ )); do
            for (( lineCnt=1; lineCnt<${beLines[0]}; lineCnt++ )); do
                solveLine=`echo "$otherLines" | sed -n "${lineCnt}p"`
                local strInBrace=`GetStrInBrace "$solveLine"`
                local array=`GetDataSplitWave "$strInBrace"`
                not test here
                read -ra array <<< $array
                array=($array)
                local strTmp=`ReplaceBrace "$solveLine" "${array[$bindCnt]}"`
                Push "$strTmp"
            done
            local restLines=`echo "$otherLines" | sed -n "$[${beLines[0]}+1],$ p"`
            DepartBind "$restLines" $file
            for (( lineCnt=1; lineCnt<${beLines[0]}; lineCnt++ )); do
                Pop
            done
        done
    else
        Push "$curLine"
        DepartBind "$otherLines" $file
        Pop
    fi
    return
}

###############################
# Main
tmpFile="simParameterTmp.txt"
deBindFile="simParameterDeBind.txt"
taskStartFlag=TaskBegin
taskEndFlag=TaskEnd
commentStartFlag=CommentBegin
commentEndFlag=CommentEnd
echo > $deBindFile
\cp -f simParameter.txt $tmpFile

DelNoneUseLines $tmpFile $commentStartFlag $commentEndFlag
# 1) choose the tasks.
tbLines=`cat -n $tmpFile | grep $taskStartFlag | awk '{print $1}'`
tbLines=($tbLines)
teLines=`cat -n $tmpFile | grep $taskEndFlag | awk '{print $1}'`
teLines=($teLines)
tbNum=${#tbLines[*]}
teNum=${#teLines[*]}
if [ $tbNum -ne $teNum ]; then
    echo "[Error] Numbers of TaskBegin and TaskEnd are not same!"
    exit
fi

for (( i=0; i<$tbNum; i++ )); do
    taskStr=`sed -n "${tbLines[$i]},${teLines[$i]}p" $tmpFile`
    DepartBind "$taskStr" $deBindFile
done
echo "------------this is debind file"
cat $deBindFile

echo > $tmpFile
tbLines=`cat -n $deBindFile | grep $taskStartFlag | awk '{print $1}'`
tbLines=($tbLines)
teLines=`cat -n $deBindFile | grep $taskEndFlag | awk '{print $1}'`
teLines=($teLines)
tbNum=${#tbLines[*]}
teNum=${#teLines[*]}
for (( i=0; i<$tbNum; i++ )); do
    taskStr=`sed -n "$[${tbLines[$i]}+1],$[${teLines[$i]}-1]p" $deBindFile`
    DepartTask "$taskStr" $tmpFile
done

echo "----End File----"
cat $tmpFile


