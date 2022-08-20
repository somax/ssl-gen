# ssl-gen.sh
自签名证书生成脚本

## Usage
```sh
# 1. 生成配置文件,
./sslgen.sh conf <namespace>

# 按需修改后...

# 2. 生成 Root CA
./sslgen.sh rootca <namespace>

# 3. 生成 域名证书
./sslgen.sh domain <namespace>

# 4. 检查证书
./sslgen.sh verify <namespace>
```
