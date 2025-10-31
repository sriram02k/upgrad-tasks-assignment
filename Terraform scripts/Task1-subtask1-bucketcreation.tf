#Below Block tells the terraform to use aws as its provider with region us-east-1
provider "aws"
{
region = "us-east-1"
}
#Bucket which is an aws resource will be created with name as mentioned which is
universal
resource "aws_s3_bucket" "terraform_state"
{
bucket = "buc-020401"
}