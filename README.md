# 用于快速建立KVM虚拟机的脚本

可以使用以下方法使用该脚本：

```
sudo yum install -y qemu-kvm qemu-img

sudo yum install -y libvirt virt-install

sudo yum install -y git

sudo mkdir -p /vm/images /vm/manager/iso /vm/manager/templates

cd /usr/local/share

sudo git clone https://github.com/xiangjl/easy-vm.git

ln -s /usr/local/share/easy-vm /vm/manager/easy-vm

cd /vm/manager/easy-vm

sudo ./vm-install.sh
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

sudo ./vm-install.sh new-plan
```
