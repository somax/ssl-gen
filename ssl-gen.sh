#! /bin/bash
# 此脚本用于生成自签名证书
# CreateBy: MaXiaojun 
# LastModify: 20220819

help(){
    echo "$0 [command] [option]"
    echo "$0 -c .conf [command] [option]"
    echo "commands:"
    echo "  rootca      构建自签名 root 证书" 
    echo "  domain      构建自签名域名证书" 
    echo "  verify      校验自签名域名证书" 
    echo "  gen-conf    生成配置文件"
    echo "  gen-ext     生成 v3.ext 文件"
    echo "  gen-passwd  生成 密码文件"
}


gen-conf(){
cat << EOF | tee $CONF_FILE
OUTPUT_PATH="./test"
PREFIX="test"
DOMAIN="test.com"
SUBJ_C="CN"
SUBJ_ST=""
SUBJ_L=""
SUBJ_ORG="test org"
SUBJ_OU=""
SUBJ_CN="Test Local Root Certification"
EXT_FILE="v3.ext"
EOF
}

gen-ext(){
cat << EOF | tee v3.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName=@alt_names

[alt_names]
DNS.1 = *.test.com
DNS.2 = *.a.test.com
IP.1 = 10.0.0.1
EOF
}


gen-passwd(){
  echo "输入密码:"
  read -s PASSWD
  echo $PASSWD > .passwd
}

rootca(){

    echo "1-> 生成 Root CA key..."
    mkdir -p $OUTPUT_PATH
    KEY_FILE="${OUTPUT_PATH}/${PREFIX}-rootCA.key"
    if [ -f "${KEY_FILE}" ]; then
        echo "'${KEY_FILE}' 已存在, 如需重新生成请先删除"
    else
        # Create Root CA (Done once)
        openssl genrsa \
            -des3 \
            -passout file:.passwd \
            -out ${KEY_FILE} \
            4096
    fi

    echo "2-> 生成 Root Certificate..."
    CRT_FILE="${OUTPUT_PATH}/${PREFIX}-rootCA.crt"
    if [ -f "${CRT_FILE}" ]; then
        echo "'${CRT_FILE}' 已存在, 如需重新生成请先删除"
    else
        ## Create and self sign the Root Certificate
        openssl req \
            -x509 \
            -new \
            -nodes \
            -key ${KEY_FILE} \
            -passin file:.passwd \
            -sha256 \
            -days 3650 \
            -out ${CRT_FILE} \
            -subj "/C=${SUBJ_C}/ST=${SUBJ_ST}/L=${SUBJ_L}/O=${SUBJ_ORG}/OU=${SUBJ_OU}/CN=${SUBJ_CN}"
    fi

}


domain(){
    shift
    echo $1

    ROOT_KEY_FILE="${OUTPUT_PATH}/${PREFIX}-rootCA.key"
    ROOT_CRT_FILE="${OUTPUT_PATH}/${PREFIX}-rootCA.crt"
    DOMAIN_CSR_FILE="${OUTPUT_PATH}/${DOMAIN}.csr"
    DOMAIN_KEY_FILE="${OUTPUT_PATH}/${DOMAIN}.key"
    DOMAIN_CRT_FILE="${OUTPUT_PATH}/${DOMAIN}.crt"

    # Create the signing (csr)
    echo "1-> 生成 (csr)..."
    if [ -f "${DOMAIN_CSR_FILE}" ]; then
        echo "'${DOMAIN_CSR_FILE}' 已存在, 如需重新生成请先删除"
    else
        openssl req \
            -new \
            -sha256 \
            -nodes \
            -out ${DOMAIN_CSR_FILE} \
            -newkey rsa:2048 \
            -keyout ${DOMAIN_KEY_FILE} \
            -subj "/C=${SUBJ_C}/ST=${SUBJ_ST}/L=${SUBJ_L}/O=${SUBJ_ORG}/OU=${SUBJ_OU}/CN=${DOMAIN}"
    fi


    # Generate the certificate using the domain csr and key along with the CA Root key
    echo "2-> 生成自签名证书..."
    if [ -f "${DOMAIN_CRT_FILE}" ]; then
        echo "'${DOMAIN_CRT_FILE}' 已存在, 如需重新生成请先删除"
    else
        if [ -f $EXT_FILE ]; then
            openssl x509 \
                -req \
                -in ${DOMAIN_CSR_FILE} \
                -CA ${ROOT_CRT_FILE} \
                -CAkey ${ROOT_KEY_FILE} \
                -CAcreateserial \
                -out ${DOMAIN_CRT_FILE} \
                -days 3650 \
                -sha256 \
                -extfile $EXT_FILE \
                -passin file:.passwd
        else
            echo "\"$EXT_FILE\" 不存在, 要自动创建吗?(Y/n)"
            read -n 1 -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo
                gen-ext
                echo "创建完成, 请修改 $EXT_FILE 后重新运行命令."
            fi
        fi

    fi
}



verify(){

    DOMAIN_CSR_FILE="${OUTPUT_PATH}/${DOMAIN}.csr"
    DOMAIN_CRT_FILE="${OUTPUT_PATH}/${DOMAIN}.crt"

    # Verify the csr's content
    echo "-> Verify ${DOMAIN_CSR_FILE}:"
    openssl req -in ${DOMAIN_CSR_FILE} -noout -text

    # Verify the certificate's content
    echo "-> Verify ${DOMAIN_CRT_FILE}:"
    openssl x509 -in ${DOMAIN_CRT_FILE} -noout -text

}




# main
if [ "$1" == "" ]; then
    help
fi

if [ "$1" == "-c" ]; then
    CONF_FILE="$2"
    shift
    shift
else 
    CONF_FILE=".conf"
fi

echo "=>>" $@ $CONF_FILE

if [ -f "$CONF_FILE" ]; then
    . $CONF_FILE

    # run command
    $1 $@
else
    echo "\"$CONF_FILE\" 不存在, 要自动创建吗?(Y/n)"
    read -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        gen-conf
        echo "创建完成, 请修改 $CONF_FILE 后重新运行命令."
    fi
fi

