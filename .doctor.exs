# Documentation coverage gate (`mix doctor`). Every module needs a @moduledoc,
# every public function a @doc and a @spec - the same bar the ExDoc output is
# judged by. The demo apps' OTP `Application` modules are boilerplate ExDoc
# hides anyway - anchored, so `SetmyInfo.Commons.Config.Application` (a real
# library module) stays in.
%Doctor.Config{
  ignore_modules: [~r/^SetmyInfo\.DemoModule[A-D]\.Application$/],
  ignore_paths: [],
  min_module_doc_coverage: 100,
  min_module_spec_coverage: 100,
  min_overall_doc_coverage: 100,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 100,
  moduledoc_required: true,
  exception_moduledoc_required: true,
  raise: false,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: true,
  umbrella: true,
  failed: false
}
