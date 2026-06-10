# -*- coding: UTF-8 -*-
"""
Document Module for Revit MCP
Save / persistence operations for the active document.

Note: Save / SaveAs must NOT run inside a Transaction — these handlers
deliberately do not open one.
"""

from pyrevit import routes, revit, DB
import json
import os
import logging

logger = logging.getLogger(__name__)


def register_document_routes(api):
    """Register document persistence routes with the API."""

    @api.route("/save_document/", methods=["POST"])
    def save_document(doc, request):
        """
        Save the active document. If a file_path is given (or the document has
        never been saved, e.g. it was started from a template), performs SaveAs;
        otherwise saves in place.

        Payload (all optional):
        {
            "file_path": "C:\\\\path\\\\to\\\\Model.rvt",
            "overwrite": true
        }
        """
        try:
            if not doc:
                return routes.make_response(
                    data={"error": "No active Revit document"}, status=503
                )

            data = {}
            if request and request.data:
                data = json.loads(request.data) if isinstance(request.data, str) else request.data

            file_path = data.get("file_path")
            overwrite = bool(data.get("overwrite", True))

            # A document started from a template (or never saved) has no real
            # path on disk yet, so it must be SaveAs'd to an explicit location.
            is_new = True
            try:
                is_new = doc.IsModelInPlace if hasattr(doc, "IsModelInPlace") else False
            except Exception:
                pass
            path_on_disk = ""
            try:
                path_on_disk = doc.PathName or ""
            except Exception:
                path_on_disk = ""

            if file_path:
                # Ensure parent directory exists
                try:
                    parent = os.path.dirname(file_path)
                    if parent and not os.path.exists(parent):
                        os.makedirs(parent)
                except Exception as mk_err:
                    logger.warning("Could not create directory: {}".format(str(mk_err)))

                save_opts = DB.SaveAsOptions()
                save_opts.OverwriteExistingFile = overwrite
                model_path = DB.ModelPathUtils.ConvertUserVisiblePathToModelPath(file_path)
                doc.SaveAs(model_path, save_opts)
                return routes.make_response(data={
                    "status": "success",
                    "operation": "save_as",
                    "file_path": file_path,
                    "message": "Document saved to {}".format(file_path),
                })

            if not path_on_disk:
                return routes.make_response(
                    data={
                        "error": "Document has never been saved — provide a file_path to save it (e.g. C:\\\\Models\\\\ESB.rvt)."
                    },
                    status=400,
                )

            # Save in place
            doc.Save()
            return routes.make_response(data={
                "status": "success",
                "operation": "save",
                "file_path": path_on_disk,
                "message": "Document saved",
            })

        except Exception as e:
            logger.error("save_document failed: {}".format(str(e)))
            return routes.make_response(
                data={"error": str(e)}, status=500
            )

    logger.info("Document routes registered successfully")
