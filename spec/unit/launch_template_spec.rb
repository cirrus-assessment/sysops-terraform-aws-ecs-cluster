# frozen_string_literal: true

require 'spec_helper'

describe 'Launch Template' do
  let(:component) do
    var(role: :root, name: 'component')
  end
  let(:dep_id) do
    var(role: :root, name: 'deployment_identifier')
  end
  let(:region) do
    var(role: :root, name: 'region')
  end

  before(:context) do
    @plan = plan(role: :root)
  end

  it 'exists' do
    expect(@plan)
      .to(include_resource_creation(type: 'aws_launch_template')
            .once)
  end

  it 'has default instance type' do
    expect(@plan)
      .to(include_resource_creation(type: 'aws_launch_template')
            .with_attribute_value(:instance_type, 't2.medium'))
  end

  context 'when using latest amazon linux 2 optimised for ECS' do
    let(:latest_amazon_linux_2_ecs_optimised_ami_id) do
      ec2_client = Aws::EC2::Client.new(region:)

      response = ec2_client.describe_images(
        {
          owners: ['amazon'],
          filters: [
            {
              name: 'name',
              values: ['amzn2-ami-ecs-hvm-*-x86_64-ebs']
            }
          ]
        }
      )
      most_recent_image = response.images.max_by do |image|
        DateTime.parse(image.creation_date)
      end

      most_recent_image.image_id
    end

    it 'uses latest image id' do
      expect(@plan)
        .to(include_resource_creation(type: 'aws_launch_template')
              .with_attribute_value(
                :image_id,
                latest_amazon_linux_2_ecs_optimised_ami_id
              ))
    end
  end

  context 'when AMIs specified' do
    ami_id = 'custom_ami_id'

    before(:context) do
      region = var(role: :root, name: 'region')
      @plan = plan(role: :root) do |vars|
        vars.cluster_instance_amis = "{#{region}=\"#{ami_id}\"}"
      end
    end

    it 'uses provided image ID' do
      expect(@plan)
        .to(include_resource_creation(type: 'aws_launch_template')
              .with_attribute_value(
                :image_id,
                ami_id
              ))
    end
  end

  it 'has instance profile' do
    expect(@plan)
      .to(include_resource_creation(type: 'aws_launch_template')
            .with_attribute_value(
              [:iam_instance_profile, 0, :name],
              "cluster-instance-profile-#{component}-#{dep_id}-default"
            ))
  end

  describe 'launch template name prefix' do
    it 'contains component, deployment identifier and cluster name' do
      expect(@plan)
        .to(include_resource_creation(type: 'aws_launch_template')
              .with_attribute_value(
                :name_prefix,
                "cluster-#{component}-#{dep_id}-default-"
              ))
    end
  end

  describe 'monitoring' do
    it 'is enabled by default' do
      expect(@plan)
        .to(include_resource_creation(type: 'aws_launch_template')
              .with_attribute_value(
                [:monitoring, 0, :enabled],
                true
              ))
    end
  end

  describe 'root block device' do
    it 'uses the default specified size' do
      expect(@plan)
        .to(include_resource_creation(type: 'aws_launch_template')
              .with_attribute_value(
                [:block_device_mappings, 0, :ebs, 0, :volume_size],
                30
              ))
    end

    it 'uses the default specified type' do
      expect(@plan)
        .to(include_resource_creation(type: 'aws_launch_template')
              .with_attribute_value(
                [:block_device_mappings, 0, :ebs, 0, :volume_type],
                'standard'
              ))
    end

    it 'uses the default specified device name' do
      expect(@plan)
        .to(include_resource_creation(type: 'aws_launch_template')
              .with_attribute_value(
                [:block_device_mappings, 0, :device_name],
                '/dev/sda1'
              ))
    end
  end

  context 'when root block device path is specified' do
    device_path = '/custom/path'

    before(:context) do
      @plan = plan(role: :root) do |vars|
        vars.cluster_instance_root_block_device_path = device_path
      end
    end

    it 'uses provided device path' do
      expect(@plan)
        .to(include_resource_creation(type: 'aws_launch_template')
              .with_attribute_value(
                [:block_device_mappings, 0, :device_name],
                device_path
              ))
    end
  end

  context 'when enable detailed monitoring is specified' do
    enable_detailed_monitoring = false

    before(:context) do
      @plan = plan(role: :root) do |vars|
        vars.enable_detailed_monitoring = enable_detailed_monitoring
      end
    end

    it 'uses provided enable monitoring' do
      expect(@plan)
        .to(include_resource_creation(type: 'aws_launch_template')
              .with_attribute_value(
                [:monitoring, 0, :enabled],
                enable_detailed_monitoring
              ))
    end
  end
end
