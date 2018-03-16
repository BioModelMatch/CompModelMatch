require 'test_helper'
require 'openbis_test_helper'

class OpenbisEndpointTest < ActiveSupport::TestCase
  def setup
    mock_openbis_calls
  end

  test 'validation' do
    project = Factory(:project)
    endpoint = OpenbisEndpoint.new project: project, username: 'fred', password: '12345',
                                   web_endpoint: 'http://my-openbis.org/openbis',
                                   as_endpoint: 'http://my-openbis.org/openbis',
                                   dss_endpoint: 'http://my-openbis.org/openbis',
                                   space_perm_id: 'mmmm',
                                   refresh_period_mins: 60

    assert endpoint.valid?
    endpoint.username = nil
    refute endpoint.valid?
    endpoint.username = 'fred'
    assert endpoint.valid?

    endpoint.password = nil
    refute endpoint.valid?
    endpoint.password = '12345'
    assert endpoint.valid?

    endpoint.space_perm_id = nil
    refute endpoint.valid?
    endpoint.space_perm_id = 'mmmmm'
    assert endpoint.valid?

    endpoint.as_endpoint = nil
    refute endpoint.valid?
    endpoint.as_endpoint = 'fish'
    refute endpoint.valid?
    endpoint.as_endpoint = 'http://my-openbis.org/openbis'
    assert endpoint.valid?

    endpoint.dss_endpoint = nil
    refute endpoint.valid?
    endpoint.dss_endpoint = 'fish'
    refute endpoint.valid?
    endpoint.dss_endpoint = 'http://my-openbis.org/openbis'
    assert endpoint.valid?

    endpoint.web_endpoint = nil
    refute endpoint.valid?
    endpoint.web_endpoint = 'fish'
    refute endpoint.valid?
    endpoint.web_endpoint = 'http://my-openbis.org/openbis'
    assert endpoint.valid?

    endpoint.refresh_period_mins = nil
    refute endpoint.valid?
    endpoint.refresh_period_mins = 0
    refute endpoint.valid?
    endpoint.refresh_period_mins = 10
    refute endpoint.valid?
    endpoint.refresh_period_mins = 60
    assert endpoint.valid?

    endpoint.project = nil
    refute endpoint.valid?
    endpoint.project = Factory(:project)
    assert endpoint.valid?

    endpoint.policy = nil
    refute endpoint.valid?
  end

  test 'default refresh period' do
    assert_equal 120, OpenbisEndpoint.new.refresh_period_mins
  end

  test 'validates uniqueness' do
    endpoint = Factory(:openbis_endpoint)
    endpoint2 = Factory.build(:openbis_endpoint)
    assert endpoint.valid? # different project
    endpoint2 = Factory.build(:openbis_endpoint, project: endpoint.project)
    refute endpoint2.valid?
    endpoint2.as_endpoint = 'http://fish.com'
    assert endpoint2.valid?
    endpoint2.as_endpoint = endpoint.as_endpoint
    refute endpoint2.valid?
    endpoint2.dss_endpoint = 'http://fish.com'
    assert endpoint2.valid?
  end

  test 'default policy' do
    endpoint = OpenbisEndpoint.new
    refute_nil endpoint.policy
  end

  test 'link to project' do
    pa = Factory(:project_administrator)
    project = pa.projects.first
    User.with_current_user(pa.user) do
      with_config_value :openbis_enabled, true do
        endpoint = OpenbisEndpoint.create project: project, username: 'fred', password: '12345', as_endpoint: 'http://my-openbis.org/openbis', dss_endpoint: 'http://my-openbis.org/openbis', web_endpoint: 'http://my-openbis.org/openbis', space_perm_id: 'aaa'
        endpoint2 = OpenbisEndpoint.create project: project, username: 'fred', password: '12345', as_endpoint: 'http://my-openbis.org/openbis', dss_endpoint: 'http://my-openbis.org/openbis', web_endpoint: 'http://my-openbis.org/openbis', space_perm_id: 'bbb'
        endpoint.save!
        endpoint2.save!
        project.reload
        assert_equal [endpoint, endpoint2].sort, project.openbis_endpoints.sort
      end
    end
  end

  test 'can_create' do
    User.with_current_user(Factory(:project_administrator).user) do
      with_config_value :openbis_enabled, true do
        assert OpenbisEndpoint.can_create?
      end

      with_config_value :openbis_enabled, false do
        refute OpenbisEndpoint.can_create?
      end
    end

    User.with_current_user(Factory(:person).user) do
      with_config_value :openbis_enabled, true do
        refute OpenbisEndpoint.can_create?
      end

      with_config_value :openbis_enabled, false do
        refute OpenbisEndpoint.can_create?
      end
    end

    User.with_current_user(nil) do
      with_config_value :openbis_enabled, true do
        refute OpenbisEndpoint.can_create?
      end

      with_config_value :openbis_enabled, false do
        refute OpenbisEndpoint.can_create?
      end
    end
  end

  test 'can_delete?' do
    person = Factory(:person)
    ep = Factory(:openbis_endpoint, project: person.projects.first)
    refute ep.can_delete?(person.user)
    User.with_current_user(person.user) do
      refute ep.can_delete?
    end

    pa = Factory(:project_administrator)
    ep = Factory(:openbis_endpoint, project: pa.projects.first)
    assert ep.can_delete?(pa.user)
    User.with_current_user(pa.user) do
      assert ep.can_delete?
    end

    another_pa = Factory(:project_administrator)
    refute ep.can_delete?(another_pa.user)
    User.with_current_user(another_pa.user) do
      refute ep.can_delete?
    end

    # cannot delete if linked
    # first check another linked endpoint doesn't prevent delete
    refute_nil openbis_linked_content_blob('20160210130454955-23')
    assert ep.can_delete?(pa.user)
    User.with_current_user(pa.user) do
      assert ep.can_delete?
    end

    refute_nil openbis_linked_content_blob('20160210130454955-23', ep)
    refute ep.can_delete?(pa.user)
    User.with_current_user(pa.user) do
      refute ep.can_delete?
    end
  end

  test 'available spaces' do
    endpoint = Factory(:openbis_endpoint)
    spaces = endpoint.available_spaces
    assert_equal 2, spaces.count
  end

  test 'space' do
    endpoint = Factory(:openbis_endpoint)
    space = endpoint.space
    refute_nil space
    assert_equal 'API-SPACE', space.perm_id
  end

  test 'can edit?' do
    pa = Factory(:project_administrator).user
    user = Factory(:person).user
    endpoint = OpenbisEndpoint.create project: pa.person.projects.first, username: 'fred', password: '12345', as_endpoint: 'http://my-openbis.org/openbis', dss_endpoint: 'http://my-openbis.org/openbis', space_perm_id: 'aaa'
    User.with_current_user(pa) do
      with_config_value :openbis_enabled, true do
        assert endpoint.can_edit?
      end

      with_config_value :openbis_enabled, false do
        refute endpoint.can_edit?
      end
    end

    User.with_current_user(user) do
      with_config_value :openbis_enabled, true do
        refute endpoint.can_edit?
      end

      with_config_value :openbis_enabled, false do
        refute endpoint.can_edit?
      end
    end

    User.with_current_user(nil) do
      with_config_value :openbis_enabled, true do
        refute endpoint.can_edit?
      end

      with_config_value :openbis_enabled, false do
        refute endpoint.can_edit?
      end
    end

    with_config_value :openbis_enabled, true do
      assert endpoint.can_edit?(pa)
      refute endpoint.can_edit?(user)
      refute endpoint.can_edit?(nil)

      # cannot edit if another project admin
      pa2 = Factory(:project_administrator).user
      refute endpoint.can_edit?(pa2)
    end
  end

  test 'session token' do
    endpoint = Factory(:openbis_endpoint)

    refute_nil endpoint.session_token
  end

  test 'destroy' do
    pa = Factory(:project_administrator)
    endpoint = Factory(:openbis_endpoint, project: pa.projects.first)
    metadata_store = endpoint.metadata_store
    key = endpoint.space.cache_key(endpoint.space_perm_id)
    assert metadata_store.exist?(key)
    assert_difference('OpenbisEndpoint.count', -1) do
      User.with_current_user(pa.user) do
        endpoint.destroy
      end
    end
    refute metadata_store.exist?(key)
  end

  test 'clear metadata store' do
    endpoint = Factory(:openbis_endpoint)
    key = endpoint.space.cache_key(endpoint.space_perm_id)
    assert endpoint.metadata_store.exist?(key)
    endpoint.clear_metadata_store
    refute endpoint.metadata_store.exist?(key)
  end

  test 'create_refresh_metadata_job' do
    endpoint = Factory(:openbis_endpoint)
    Delayed::Job.destroy_all
    refute OpenbisEndpointCacheRefreshJob.new(endpoint).exists?
    assert_difference('Delayed::Job.count', 1) do
      endpoint.create_refresh_metadata_job
    end
    assert_no_difference('Delayed::Job.count') do
      endpoint.create_refresh_metadata_job
    end
    assert OpenbisEndpointCacheRefreshJob.new(endpoint).exists?
  end

  test 'create job on creation' do
    Delayed::Job.destroy_all
    endpoint = Factory(:openbis_endpoint)
    assert OpenbisEndpointCacheRefreshJob.new(endpoint).exists?
  end

  test 'job destroyed on delete' do
    Delayed::Job.destroy_all
    pa = Factory(:project_administrator)
    endpoint = Factory(:openbis_endpoint, project: pa.projects.first)
    assert_difference('Delayed::Job.count', -1) do
      User.with_current_user(pa.user) do
        endpoint.destroy
      end
    end
    refute OpenbisEndpointCacheRefreshJob.new(endpoint).exists?
  end

  test 'encrypted password' do
    endpoint = OpenbisEndpoint.new project: Factory(:project), username: 'fred', password: 'frog',
                                   web_endpoint: 'http://my-openbis.org/openbis',
                                   as_endpoint: 'http://my-openbis.org/openbis',
                                   dss_endpoint: 'http://my-openbis.org/openbis',
                                   space_perm_id: 'mmmm',
                                   refresh_period_mins: 60
    assert_equal 'frog', endpoint.password
    refute_nil endpoint.encrypted_password
    refute_nil endpoint.encrypted_password_iv

    disable_authorization_checks do
      assert endpoint.save
    end

    endpoint = OpenbisEndpoint.find(endpoint.id)
    assert_equal 'frog', endpoint.password
    refute_nil endpoint.encrypted_password
    refute_nil endpoint.encrypted_password_iv
  end

  test 'follows external_assets' do

    endpoint = Factory(:openbis_endpoint)

    zample = Seek::Openbis::Zample.new(endpoint, '20171002172111346-37')
    options = { tomek: false }

    asset1 = OpenbisExternalAsset.build(zample, options)

    dataset = Seek::Openbis::Dataset.new(endpoint, '20160210130454955-23')
    asset2 = OpenbisExternalAsset.build(dataset, options)

    endpoint2 = Factory(:openbis_endpoint, refresh_period_mins: 60, web_endpoint: 'https://openbis-api.fair-dom.org/openbis2', space_perm_id: 'API-SPACE2')


    zample2 = Seek::Openbis::Zample.new(endpoint2, '20171002172111346-37')
    asset3 = OpenbisExternalAsset.build(zample2, options)

    assert asset1.save
    assert asset2.save
    assert asset3.save!

    endpoint.reload
    endpoint2.reload

    assert_equal [asset1, asset2], endpoint.external_assets.to_ary
    assert_equal [asset3], endpoint2.external_assets.to_ary

  end

  test 'registered_datafiles finds only own datafiles' do
    endpoint1 = OpenbisEndpoint.new project: Factory(:project), username: 'fred', password: 'frog',
                                    web_endpoint: 'http://my-openbis.org/doesnotmatter',
                                    as_endpoint: 'http://my-openbis.org/doesnotmatter',
                                    dss_endpoint: 'http://my-openbis.org/doesnotmatter',
                                    space_perm_id: 'space1',
                                    refresh_period_mins: 60

    endpoint2 = OpenbisEndpoint.new project: Factory(:project), username: 'fred', password: 'frog',
                                    web_endpoint: 'http://my-openbis.org/doesnotmatter',
                                    as_endpoint: 'http://my-openbis.org/doesnotmatter',
                                    dss_endpoint: 'http://my-openbis.org/doesnotmatter',
                                    space_perm_id: 'space2',
                                    refresh_period_mins: 60

    disable_authorization_checks do
      assert endpoint1.save
      assert endpoint2.save
    end

    datafile1 = Seek::Openbis::Dataset.new(endpoint1, '20160210130454955-23').create_seek_datafile
    assert datafile1.save
    datafile2 = Seek::Openbis::Dataset.new(endpoint1, '20160215111736723-31').create_seek_datafile
    assert datafile2.save
    datafile3 = Seek::Openbis::Dataset.new(endpoint2, '20160210130454955-23').create_seek_datafile
    assert datafile3.save

    df = endpoint1.registered_datafiles
    assert_includes df, datafile1
    assert_includes df, datafile2
    assert_not_includes df, datafile3

    df = endpoint2.registered_datafiles
    assert_equal [datafile3], df
  end

  test 'registered_datasets gives only own datafiles' do
    endpoint1 = Factory :openbis_endpoint

    endpoint2 = Factory :openbis_endpoint

    disable_authorization_checks do
      assert endpoint1.save
      assert endpoint2.save
    end

    set1 = Seek::Openbis::Dataset.new(endpoint1, '20160210130454955-23')
    asset1 = OpenbisExternalAsset.build(set1)
    df1 = Factory :data_file
    asset1.seek_entity = df1
    assert asset1.save

    set2= Seek::Openbis::Dataset.new(endpoint1, '20160215111736723-31')
    asset2 = OpenbisExternalAsset.build(set2)
    df2 = Factory :data_file
    asset2.seek_entity = df2
    assert asset2.save

    set3 = Seek::Openbis::Dataset.new(endpoint2, '20160210130454955-23')
    asset3 = OpenbisExternalAsset.build(set3)
    df3 = Factory :data_file
    asset3.seek_entity = df3
    assert asset3.save

    registered = endpoint1.registered_datasets
    assert_equal 2, registered.count

    registered.each do |e|
      assert e.is_a? DataFile
    end

    registered = endpoint2.registered_datasets
    assert_equal 1, registered.count
  end

  test 'registered_assays gives own zamples registered in seek as assays' do
    endpoint1 = Factory :openbis_endpoint

    zample1 = zample_for_id('12', endpoint1)

    zample2 = zample_for_id('12')

    zample3 = zample_for_id('13', endpoint1)

    asset1 = OpenbisExternalAsset.build(zample1)
    asset1.seek_entity = Factory :assay

    asset2 = OpenbisExternalAsset.build(zample2)
    asset2.seek_entity = Factory :assay

    asset3 = OpenbisExternalAsset.build(zample3)
    asset3.seek_entity = Factory :assay

    assert asset1.save
    assert asset2.save
    assert asset3.save

    assert_equal 3, OpenbisExternalAsset.count

    assert_equal 2, endpoint1.registered_assays.count

    endpoint1.registered_assays.each do |e|
      assert e.is_a? Assay
    end

    assert_equal 1, zample2.openbis_endpoint.registered_assays.count

  end

  def zample_for_id(permId = nil, endpoint = nil)

    endpoint ||= Factory :openbis_endpoint

    json = JSON.parse(
        '
{"identifier":"\/API-SPACE\/TZ3","modificationDate":"2017-10-02 18:09:34.311665","registerator":"apiuser",
"code":"TZ3","modifier":"apiuser","permId":"20171002172111346-37",
"registrationDate":"2017-10-02 16:21:11.346421","datasets":["20171002172401546-38","20171002190934144-40","20171004182824553-41"]
,"sample_type":{"code":"TZ_FAIR_ASSAY","description":"For testing sample\/assay mapping with full metadata"},"properties":{"DESCRIPTION":"Testing sample assay with a dataset. Zielu","NAME":"Tomek First"},"tags":[]}
'
    )
    json["permId"] = permId if permId
    Seek::Openbis::Zample.new(endpoint).populate_from_json(json)
  end

  # test 'reindex_entities queues new indexing job' do
  #  endpoint = Factory(:openbis_endpoint)
  #  datafile1 = Seek::Openbis::Dataset.new(endpoint, '20160210130454955-23').create_seek_datafile
  #  assert datafile1.save
  #  Delayed::Job.destroy_all
  #  # don't know how to test that it was really reindexing job with correct content
  #  assert_difference('Delayed::Job.count', 1) do
  #    endpoint.reindex_entities
  #  end
  #  assert ReindexingQueue.exists?(item: datafile1)
  # end

  # it should actually test for synchronization but I don't know how to achieve it
  # needs OpenBIS mock that can be set to return particular values
  test 'refresh_metadata clears store, marks for refresh and adds sync job' do
    endpoint = Factory(:openbis_endpoint)

    dataset = Seek::Openbis::Dataset.new(endpoint, '20160210130454955-23')
    asset = OpenbisExternalAsset.build(dataset)
    asset.synchronized_at = DateTime.now - 1.days
    assert asset.save

    key = 'TZ'
    store = endpoint.metadata_store
    store.fetch(key) do
      'Tomek'
    end

    assert_equal 'Tomek', store.fetch(key)

    Delayed::Job.destroy_all
    #assert_difference('Delayed::Job.count', 1) do
    endpoint.refresh_metadata
    #end

    refute endpoint.metadata_store.exist?(key)
    asset.reload
    assert asset.refresh?

    assert OpenbisSyncJob.new(endpoint).exists?

  end

  test 'due_to_refresh gives synchronized assets with elapsed synchronization time' do

    endpoint = Factory(:openbis_endpoint)
    endpoint.refresh_period_mins = 80
    disable_authorization_checks do
      assert endpoint.save!
    end


    assets = []
    (0..9).each do |i|

      asset = ExternalAsset.new
      asset.seek_service = endpoint
      asset.external_service = endpoint.web_endpoint
      asset.external_id = i
      asset.sync_state = :synchronized
      asset.synchronized_at= DateTime.now - i.hours
      assert asset.save
      assets << asset
    end


    assets[9].sync_state = :refresh
    assets[9].save

    assets[8].sync_state = :failed
    assets[8].save

    endpoint.reload
    assert_equal 10, endpoint.external_assets.count

    assert_equal 6, endpoint.due_to_refresh.count
    assert_equal assets[2..7].map { |r| r.external_id }, endpoint.due_to_refresh.map { |r| r.external_id }


  end

  test 'mark_for_refresh sets sync status for all due to refresh' do

    endpoint = Factory(:openbis_endpoint)
    endpoint.refresh_period_mins = 80
    disable_authorization_checks do
      assert endpoint.save!
    end

    assets = []
    (0..9).each do |i|

      asset = ExternalAsset.new
      asset.seek_service = endpoint
      asset.external_service = endpoint.web_endpoint
      asset.external_id = i
      asset.sync_state = :synchronized
      asset.synchronized_at= DateTime.now - i.hours
      assert asset.save
      assets << asset
    end


    assets[9].sync_state = :failed
    assets[9].save

    endpoint.reload
    assert_equal 10, endpoint.external_assets.count

    endpoint.mark_for_refresh

    assets.each &:reload

    assert assets[9].failed?
    assert assets[0].synchronized?
    assert assets[1].synchronized?
    assets[2..8].each { |a| assert a.refresh? }
  end

  test 'build_meta_config makes valid hash even on nil parameters' do
    endpoint = Factory(:openbis_endpoint)
    conf = endpoint.build_meta_config(nil, nil)
    exp = { study_types: [], assay_types: [] }
    assert_equal exp, conf

    conf = endpoint.build_meta_config(['st1','st2'], ['a1'])
    exp = { study_types: ['st1','st2'], assay_types: ['a1'] }
    assert_equal exp, conf
  end

  test 'build_meta_config raise exception if not empty non-table parameters' do
    endpoint = Factory(:openbis_endpoint)

    assert_raise do
      endpoint.build_meta_config('a', nil)
    end
    assert_raise do
      endpoint.build_meta_config(nil, 'b')
    end
  end

  test 'default_meta_config is set with standard OpenBIS ELN types' do
    endpoint = Factory(:openbis_endpoint)
    conf = endpoint.default_meta_config
    exp = { study_types: ['DEFAULT_EXPERIMENT'], assay_types: ['EXPERIMENTAL_STEP'] }
    assert_equal exp, conf
  end

  test 'add_meta_config sets default config on empty' do
    endpoint = Factory(:openbis_endpoint)
    endpoint.meta_config_json = nil

    endpoint.add_meta_config
    assert_equal endpoint.default_meta_config.to_json, endpoint.meta_config_json

    endpoint.meta_config_json = '{}'
    endpoint.add_meta_config
    assert_equal '{}', endpoint.meta_config_json
  end

  test 'default config is added even if not set' do
    endpoint = Factory(:openbis_endpoint)
    assert_equal endpoint.default_meta_config.to_json, endpoint.meta_config_json
  end

  test 'meta_config is deserialized json verion' do
    endpoint = Factory(:openbis_endpoint)
    conf = { study_types: ['E1'], assay_types: ['A2'] }

    endpoint.meta_config=conf
    assert_same conf, endpoint.meta_config
    assert_equal conf.to_json, endpoint.meta_config_json

    disable_authorization_checks do
      endpoint.save!
    end

    endpoint2 = OpenbisEndpoint.find(endpoint.id)
    assert_not_same endpoint, endpoint2

    assert_equal conf.to_json, endpoint2.meta_config_json
    assert_equal conf, endpoint2.meta_config

  end

  test 'study_types gives default if not configured' do
    endpoint = Factory(:openbis_endpoint)
    assert_equal ['DEFAULT_EXPERIMENT'], endpoint.study_types
  end

  test 'study_types gives empty on missing' do
    endpoint = Factory(:openbis_endpoint)
    endpoint.meta_config = {}
    assert_equal [], endpoint.study_types
  end

  test 'study_types gives what configured' do
    endpoint = Factory(:openbis_endpoint)
    endpoint.meta_config = {study_types: ['a']}
    assert_equal ['a'], endpoint.study_types
  end

  test 'assay_types gives default if not configured' do
    endpoint = Factory(:openbis_endpoint)
    assert_equal ['EXPERIMENTAL_STEP'], endpoint.assay_types
  end

  test 'assay_types gives empty on missing' do
    endpoint = Factory(:openbis_endpoint)
    endpoint.meta_config = {}
    assert_equal [], endpoint.assay_types
  end

  test 'assay_types gives what configured' do
    endpoint = Factory(:openbis_endpoint)
    endpoint.meta_config = {assay_types: ['a']}
    assert_equal ['a'], endpoint.assay_types
  end

end
