# 用于快速建立KVM虚拟机的脚本

可以使用以下方法使用该脚本：

```
yum install -y qemu-kvm qemu-img

yum install -y libvirt virt-install

yum install -y git

mkdir -p /vm/images /vm/manager/iso /vm/manager/templates

cd /usr/share

git clone https://github.com/xiangjl/easy-vm.git

ln -s /usr/share/easy-vm /vm/manager/shell

cd /vm/manager/shell

./vm-install.sh
```

如果您不希望每次输入所有可选的虚拟机配置，您可以尝试修改配置文件：

```
cd /vm/manager/shell/plans

vi default
```

您也可以创建多个配置文件，以方便快速建立不同配置的虚拟机：

```
cd /vm/manager/shell/plans

cp default new-plan

vi new-plan

cd ..

./vm-install.sh new-plan
```
