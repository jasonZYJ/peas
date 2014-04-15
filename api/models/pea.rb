# An individual docker container
class Pea
  include Mongoid::Document
  field :port, type: String
  field :docker_id, type: String
  field :process_type, type: String
  field :host, type: String
  belongs_to :app
  validates_presence_of :port, :docker_id, :app

  def initialize docker_id
    version_check
    @container = Docker::Container.get(docker_id)
    super
  end

  # Issue a warning if the host's version of Docker is newer than the version Peas is tested against
  def version_check
    if Gem::Version.new(Docker.version['Version']) > Gem::Version.new(Peas::DOCKER_VERSION)
      Peas::Application.logger.warn "Using version #{Docker.version['Version']} of Docker \
which is newer than the latest version Peas has been tested with (#{Peas::DOCKER_VERSION})"
    end
  end

  # Before persisting a pea create a running container with the parent app using the specified process type
  before_create do |pea|
    container = Docker::Container.create(
      'Cmd' => ['/bin/bash', '-c', "/start #{pea.process_type}"],
      'Image' => pea.name,
      'Env' => 'PORT=5000',
      'ExposedPorts' => {
        '5000' => {}
      }
    ).start(
      'PublishAllPorts' => 'true'
    )
    pea.docker_id = container.info['id']
    pea.port = container.json['NetworkSettings']['Ports']['5000'].first['HostPort']
  end

  # Before removing a pea from the database kill the relevant app container
  before_destroy do |pea|
    pea.docker.kill
  end

  def docker
    @container
  end

  # Return whether an app container is running or not
  def running?
    @container.json['State']['Running']
  end
end