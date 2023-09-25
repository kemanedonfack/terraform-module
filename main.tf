module "network" {
  source                     = "./modules/network"
  vpc_cidr                   = "10.0.0.0/16"
  vpc_name                   = "devsecops-pipeline-vpc"
  igw_name                   = "devsecops-pipeline-gw"
  public_subnet_cidr_blocks  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidr_blocks = ["10.0.4.0/24", "10.0.5.0/24"]
  availability_zones         = ["eu-north-1a", "eu-north-1b"]
  public_subnet_name_prefix  = "devsecops-pipeline-public-subnet"
  private_subnet_name_prefix = "devsecops-pipeline-private-subnet"
  public_rt_name             = "devsecops-pipeline-public-rt"
  private_rt_name            = "devsecops-pipeline-private-rt"
}

module "iam_role" {
  source                    = "./modules/iam-role"
  policy_name               = "Jenkins-instance-policy"
  role_name                 = "jenkins-iam-role"
  iam_instance_profile_name = "jenkins-instance-profile"
  assume_role_statement = [
    {
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = "RoleForEC2"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }
  ]
  policy_statements = [
    {
      Effect   = "Allow",
      Action   = "ecr:*",
      Resource = "*"
    },
    {
      Effect = "Allow"
      Action = [
        "s3:Get*",
        "s3:List*",
        "s3-object-lambda:Get*",
        "s3-object-lambda:List*",
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "*"
    }
  ]
}

module "security_group_jenkins" {
  source                     = "./modules/securitygroup"
  security_group_name        = "jenkins-sg"
  security_group_description = "Jenkins security Group"
  inbound_port               = [8080, 80, 443, 22]
  vpc_id                     = module.network.vpc_id
}

module "ec2_jenkins" {
  source                    = "./modules/ec2"
  aws_subnet_id             = module.network.public_subnet_ids[0]
  instance_name             = "jenkins"
  ami                       = "ami-08766f81ab52792ce"
  key_name                  = "kemane"
  instance_type             = "t3.medium"
  userdata                  = "jenkins_userdata.sh"
  iam_instance_profile_name = module.iam_role.instance_profile
  ebs_volume_size           = 30
  ec2_sg_id                 = [module.security_group_jenkins.security_group_id]

}

module "security_group_sonarqube" {
  source                     = "./modules/securitygroup"
  security_group_name        = "sonarqube-sg"
  security_group_description = "Sonarqube security Group"
  inbound_port               = [9000, 22]
  vpc_id                     = module.network.vpc_id
}

module "ec2_sonarqube" {
  source                    = "./modules/ec2"
  aws_subnet_id             = module.network.public_subnet_ids[0]
  instance_name             = "SonarQube server"
  ami                       = "ami-08766f81ab52792ce"
  key_name                  = "kemane"
  instance_type             = "t3.medium"
  userdata                  = "sonarqube_userdata.sh"
  iam_instance_profile_name = null
  ebs_volume_size           = 30
  ec2_sg_id                 = [module.security_group_sonarqube.security_group_id]

}

module "ecr_repo" {
  source               = "./modules/ecr"
  ecr_repo_name        = "assiduite"
  image_tag_mutability = "MUTABLE"

}

module "s3_bucket" {
  source             = "./modules/s3"
  bucket_name        = "jenkins-bucket-for-artifact-devsecops-pipeline"
  bucket_description = "Private bucket to hold Jenkins artifacts"

}
