localip           = "0.0.0.0/0"
aws_profile       = "default"
aws_region        = "eu-central-1"
key_name          = "awskey"
db_instance_class = "db.t2.micro"
dbname		  = "project_test"
dbuser		  = "user"
dbpassword	  = "pass1111"
public_key_path   = "/Users/mivanov/.ssh/id_rsa.pub"
dev_instance_type = "t2.micro"
dev_ami		  = "ami-07cda0db070313c52"
cidrs             = {
  public1	  = "10.1.1.0/24"
  private1	  = "10.1.2.0/24"
  private2  = "10.1.3.0/24"
}