#! /bin/bash
# 此脚本用于生成自签名证书
# CreateBy: MaXiaojun 
# LastModify: 20220820



help(){
    echo "usage: $0 <command> <namespace>"
    echo "commands:"
    echo "  conf <namespace>    生成配置文件"
    echo "  rootca <namespace>  构建自签名 root 证书" 
    echo "  domain <namespace>  构建自签名域名证书" 
    echo "  verify <namespace>  校验自签名域名证书" 
}

conf(){
    NAMESPACE=$2
    if [ -z "$NAMESPACE" ]; then
        echo "请指定名称空间: $0 $1 <namespace>"
        exit
    fi

    mkdir -p $NAMESPACE

    # 生成配置文件
    CONF_FILE=$NAMESPACE/$NAMESPACE.conf
    echo "📝 准备生成配置文件...$CONF_FILE:"

    if [ -f "$CONF_FILE" ]; then
        echo "...文件已存在, 跳过"
    else
        cat << EOF | tee $CONF_FILE
DOMAIN="$NAMESPACE"
SUBJ_C="CN"
SUBJ_ST="ST"
SUBJ_L="L"
SUBJ_ORG="$NAMESPACE ORG"
SUBJ_OU="OU"
SUBJ_CN="$NAMESPACE Local Root Certification"
EOF
    fi

# 生成扩展配置文件
    EXT_FILE=$NAMESPACE/$NAMESPACE.ext
    echo "📝 准备生成扩展配置文件...$EXT_FILE:"
    if [ -f "$EXT_FILE" ]; then
        echo "...文件已存在, 跳过"
    else
        cat << EOF | tee $EXT_FILE
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName=@alt_names
[alt_names]
DNS.1 = $NAMESPACE
DNS.2 = *.$NAMESPACE
IP.1 = 127.0.0.1
EOF
    fi

# 生成密码文件
    PASSWD_FILE=$NAMESPACE/$NAMESPACE.pwd
    echo "📝 准备生成密码文件...$PASSWD_FILE:"
    if [ -f "$PASSWD_FILE" ]; then
        echo "...文件已存在, 跳过"
    else
        echo "🔑 输入密码:"
        read -s PASSWD
        echo $PASSWD | base64 > $PASSWD_FILE
    fi
}



# 生成 Root CA 证书
rootca(){
    NAMESPACE=$2
    if [ -z "$NAMESPACE" ]; then
        echo "请指定名称空间: $0 $1 <namespace>"; exit 1
    fi

    CONF_FILE="./$NAMESPACE/$NAMESPACE.conf"
    if [ -f "$CONF_FILE" ]; then
        . $CONF_FILE
    else
        echo "未找到配置文件 $CONF_FILE"; exit 1
    fi

    PASSWD_FILE="./$NAMESPACE/$NAMESPACE.pwd"
    PASSWD=$(cat $PASSWD_FILE | base64 -d)
    if [ ! -f "$PASSWD_FILE" ]; then
        echo "未找到密码文件 $PASSWD_FILE"; exit 1
    fi

        echo "1✨-> 生成 Root CA key..."
        KEY_FILE="./$NAMESPACE/$NAMESPACE-rootca.key"
        if [ -f "$KEY_FILE" ]; then
            echo "'$KEY_FILE' 已存在, 跳过"
        else
            # Create Root CA (Done once)
            cat 1234 | openssl genrsa \
                -des3 \
                -passout pass:$PASSWD \
                -out $KEY_FILE \
                4096
                # -passout file:$PASSWD_FILE \
        fi

    # if [ "$0" != 0 ];then
    #     echo "创建失败!"; exit 1
    # fi

    echo "2✨-> 生成 Root Certificate..."
    CRT_FILE="./$NAMESPACE/$NAMESPACE-rootca.crt"
    if [ -f "$CRT_FILE" ]; then
        echo "'$CRT_FILE' 已存在, 跳过"
    else
        ## Create and self sign the Root Certificate
        openssl req \
            -x509 \
            -new \
            -nodes \
            -key $KEY_FILE \
            -passin pass:$PASSWD \
            -sha256 \
            -days 3650 \
            -out $CRT_FILE \
            -subj "/C=$SUBJ_C/ST=$SUBJ_ST/L=$SUBJ_L/O=$SUBJ_ORG/OU=$SUBJ_OU/CN=$SUBJ_CN"
    fi

}

# 生成域名证书
domain(){
    NAMESPACE=$2
    if [ -z "$NAMESPACE" ]; then
        echo "请指定名称空间: $0 $1 <namespace>"; exit 1
    fi

    CONF_FILE=$NAMESPACE/$NAMESPACE.conf
    if [ -f "$CONF_FILE" ]; then
        . $CONF_FILE
    else
        echo "未找到配置文件 $CONF_FILE"; exit 1
    fi


    ROOT_KEY_FILE="./$NAMESPACE/$NAMESPACE-rootca.key"
    ROOT_CRT_FILE="./$NAMESPACE/$NAMESPACE-rootca.crt"
    DOMAIN_CSR_FILE="./$NAMESPACE/$NAMESPACE.csr"
    DOMAIN_KEY_FILE="./$NAMESPACE/$NAMESPACE.key"
    DOMAIN_CRT_FILE="./$NAMESPACE/$NAMESPACE.crt"
    PASSWD_FILE="./$NAMESPACE/$NAMESPACE.pwd"
    PASSWD=$(cat $PASSWD_FILE | base64 -d)
    EXT_FILE="./$NAMESPACE/$NAMESPACE.ext"

    if [ ! -f "$ROOT_KEY_FILE" ]; then
        echo "$ROOT_KEY_FILE' 未找到, 创建失败"; exit 1
    fi
    if [ ! -f "$ROOT_CRT_FILE" ]; then
        echo "$ROOT_CRT_FILE' 未找到, 创建失败"; exit 1
    fi

    # Create the signing (csr)
    echo "1✨-> 生成 $DOMAIN_CSR_FILE ..."
    if [ -f "$DOMAIN_CSR_FILE" ]; then
        echo "'$DOMAIN_CSR_FILE' 已存在, 跳过"
    else
        openssl req \
            -new \
            -sha256 \
            -nodes \
            -out $DOMAIN_CSR_FILE \
            -newkey rsa:2048 \
            -keyout $DOMAIN_KEY_FILE \
            -subj "/C=$SUBJ_C/ST=$SUBJ_ST/L=$SUBJ_L/O=$SUBJ_ORG/OU=$SUBJ_OU/CN=$DOMAIN"
    fi


    # Generate the certificate using the domain csr and key along with the CA Root key
    echo "2✨-> 生成自签名证书..."
    if [ -f "$DOMAIN_CRT_FILE" ]; then
        echo "'$DOMAIN_CRT_FILE' 已存在, 跳过"
    else
        if [ ! -f $EXT_FILE ]; then
            echo "$EXT_FILE 不存在, $DOMAIN_CRT_FILE 创建失败"; exit 1
        fi

        openssl x509 \
        -req \
        -in $DOMAIN_CSR_FILE \
        -CA $ROOT_CRT_FILE \
        -CAkey $ROOT_KEY_FILE \
        -CAcreateserial \
        -out $DOMAIN_CRT_FILE \
        -days 3650 \
        -sha256 \
        -extfile $EXT_FILE \
        -passin pass:$PASSWD

    fi
}


# 校验证书
verify(){
    NAMESPACE=$2
    if [ -z "$NAMESPACE" ]; then
        echo "请指定名称空间: $0 $1 <namespace>"; exit 1
    fi

    DOMAIN_CSR_FILE="./$NAMESPACE/$NAMESPACE.csr"
    DOMAIN_CRT_FILE="./$NAMESPACE/$NAMESPACE.crt"

    # Verify the csr's content
    echo "✨-> Verify $DOMAIN_CSR_FILE:"
    openssl req -in $DOMAIN_CSR_FILE -noout -text

    # Verify the certificate's content
    echo "✨-> Verify $DOMAIN_CRT_FILE:"
    openssl x509 -in $DOMAIN_CRT_FILE -noout -text

}

# main
if [ "$1" == "" ]; then
    help
else
    $1 $@
fi
