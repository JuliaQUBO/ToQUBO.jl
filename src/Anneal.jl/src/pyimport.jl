using PyCall
using Conda

"""
    python_import(name, module_name::String, package_name::String)

Wrapper for pyimport_conda with support to PyPi-only packages.

## Example
julia> const neal = python_import("neal", "dwave-neal")
"""
function python_import(module_name::String, package_name::String)
    try
        return pyimport_conda(module_name, package_name)
    catch
        if PyCall.conda
            @warn "'$module_name' is not installed.\nRunning `pip install --user $package_name` (via conda)"

            try
                Conda.pip_interop(true)
                Conda.pip("install --user", "$package_name")
            catch
                throw(SystemError("Unable to install '$package_name' using pip (via conda)"))
            end
        else
            @warn "'$module_name' is not installed.\nRunning `$(PyCall.python) -m pip install --user $package_name`"

            cmd = Cmd([PyCall.python, "-m", "pip", "install", "--user", package_name])
            
            ans = run(cmd)

            if ans.exitcode != 0
                throw(SystemError("Unable to install '$package_name' using pip", ans.exitcode))
            end
        end;

        return pyimport(module_name)
    end
end