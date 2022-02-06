"""
    @python_import(name, module_name::String, package_name::String)

Wrapper for pyimport_conda with support to PyPi-only packages.

## Example
julia> @python_import neal "neal" "dwave-neal"
"""
macro python_import(name, module_name::String, package_name::String)
    return :(
        const $name = PyNULL();

        function __init__();
            try;
                copy!($name, pyimport_conda($module_name, $package_name));
            catch;
                if PyCall.conda;
                    @warn string("'", $module_name, "' is not installed.\n", "Running `pip install --user ", $package_name, "` (via conda)");

                    try;
                        Conda.pip_interop(true);
                        Conda.pip("install --user", "$package_name");
                    catch;
                        throw(SystemError("Unable to install '", $package_name, "' using pip (via conda)"));
                    end;
                else;
                    @warn string("'", $module_name, "' is not installed.\n", "Running `$(PyCall.python) -m pip install --user ", $package_name, "`");

                    cmd = Cmd([PyCall.python, "-m", "pip", "install", "--user", $package_name]);
                    
                    ans = run(cmd);

                    if ans.exitcode != 0;
                        throw(SystemError("Unable to install '", $package_name, "' using pip", ans.exitcode));
                    end
                end;

                copy!($name, pyimport($module_name));
            end;
        end;
    )
end