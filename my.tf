provider "aws" {
  region          = "ap-south-1"
  access_key 		  = "AKIA3ABYZUQJ4A7MHB6I"
  secret_key 		  = "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"
  profile         = "myuser"
}



resource "aws_security_group" "allow_security" {
  name        = "allow_security"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-57b5a83f"

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
   description = "ping-icmp"
   from_port   = -1
   to_port     = -1
   protocol    = "icmp"
   cidr_blocks = ["0.0.0.0/0"]
    }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_security"
  }
}


resource "tls_private_key" "akey" {
    algorithm   =  "RSA"
    rsa_bits    =  4096
}
resource "local_file" "private_key" {
    content         =  tls_private_key.akey.private_key_pem
    filename        =  "akey.pem"
    file_permission =  0400
}
resource "aws_key_pair" "akey" {
    key_name   = "keyterra"
    public_key = tls_private_key.akey.public_key_openssh
}



resource "aws_instance" "inst_1" {

  ami               = "ami-0447a12f28fddb066"
  instance_type     = "t2.micro"
  key_name          = "keyterra"
  availability_zone = "ap-south-1b"
  security_groups   = [ "allow_security" ]

  connection {
    type     = "ssh"
    port     =  22
    user     = "ec2-user"
    private_key = file("C:/Users/hp/Desktop/myterr/akey.pem")
    host     = aws_instance.inst_1.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "inst_1"
  }
}


resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.inst_1.availability_zone
  size              = 1
  tags = {
    Name = "vol_1"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdp"
  volume_id   = aws_ebs_volume.esb1.id
  instance_id = aws_instance.inst_1.id
  force_detach = true
}


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.inst_1.public_ip} > publicip.txt"
  	}
}



resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    port     =  22
    private_key = file("C:/Users/hp/Desktop/myterr/akey.pem")
    host     = aws_instance.inst_1.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdp",
      "sudo mount  /dev/xvdp  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Sanjayde/s3.git /var/www/html/",
      "sudo setenforce 0"
    ]
  }
}


resource "aws_s3_bucket" "fortybuck" {
  bucket = "fortybuck"
  acl    = "public-read"
  

  versioning {
    enabled = true
  }




  tags = {
    Name        = "fortybuck"
   
  }
}

locals {
  s3_origin_id = "myS3Origin"
}



resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.fortybuck.bucket
  key    = "Screenshot.png"
  source = "C:/Users/hp/Desktop/forterra/Screenshot.png"
  acl    = "public-read"
   
}

resource "aws_cloudfront_distribution" "s3_distrib" {
    default_cache_behavior {
        allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
    }
enabled             = true
origin {
        domain_name = aws_s3_bucket.fortybuck.bucket_regional_domain_name
        origin_id   = local.s3_origin_id
    }
restrictions {
        geo_restriction {
        restriction_type = "none"
        }
    }
viewer_certificate {
        cloudfront_default_certificate = true
    }


connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.inst_1.public_ip
        port    = 22
        private_key = file("C:/Users/hp/Desktop/myterr/akey.pem")
    }
provisioner "remote-exec" {
          
              inline = [
                   "sudo su << EOF",
            "echo \"<center><img src='http://${self.domain_name}/${aws_s3_bucket_object.object.key}' height='200px' width='200px'></center>\" >> /var/www/html/index.html",
            "EOF"
       
        ]
      }
}


resource "null_resource" "nulllocal1"  {


depends_on = [
    aws_cloudfront_distribution.s3_distrib
  ]

	provisioner "local-exec" {
	    command = "chrome  start  ${aws_instance.inst_1.public_ip}"
      

      
      }
}


