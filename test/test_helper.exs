{:ok, _started} = Application.ensure_all_started(:tursox_procedures)
# Keep successful runs to ExUnit's progress output. Captured logs are attached to
# the failing test when they are useful for diagnosis.
ExUnit.start(capture_log: true)
